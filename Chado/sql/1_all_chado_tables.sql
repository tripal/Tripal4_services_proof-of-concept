--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.12
-- Dumped by pg_dump version 9.5.12

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: chado; Type: SCHEMA; Schema: -; Owner: www
--

CREATE SCHEMA chado;


ALTER SCHEMA chado OWNER TO www;

--
-- Name: feature_by_fx_type; Type: TYPE; Schema: chado; Owner: www
--

CREATE TYPE chado.feature_by_fx_type AS (
	feature_id bigint,
	depth integer
);


ALTER TYPE chado.feature_by_fx_type OWNER TO www;

--
-- Name: soi_type; Type: TYPE; Schema: chado; Owner: www
--

CREATE TYPE chado.soi_type AS (
	type_id bigint,
	subject_id bigint,
	object_id bigint
);


ALTER TYPE chado.soi_type OWNER TO www;

--
-- Name: _fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    origin alias for $1;
    child_id alias for $2;
    cvid alias for $3;
    typeid alias for $4;
    depth alias for $5;
    cterm cvterm_relationship%ROWTYPE;
    exist_c int;
BEGIN
    --- RAISE NOTICE 'depth=% root=%', depth,child_id;
    --- not check type_id as it may be null and not very meaningful in cvtermpath when pathdistance > 1
    SELECT INTO exist_c count(*) FROM cvtermpath WHERE cv_id = cvid AND object_id = origin AND subject_id = child_id AND pathdistance = depth;
    IF (exist_c = 0) THEN
        INSERT INTO cvtermpath (object_id, subject_id, cv_id, type_id, pathdistance) VALUES(origin, child_id, cvid, typeid, depth);
    END IF;
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = child_id LOOP
        PERFORM _fill_cvtermpath4node(origin, cterm.subject_id, cvid, cterm.type_id, depth+1);
    END LOOP;
    RETURN 1;
END;
$_$;


ALTER FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) OWNER TO www;

--
-- Name: _fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
    origin alias for $1;
    child_id alias for $2;
    cvid alias for $3;
    typeid alias for $4;
    depth alias for $5;
    cterm cvterm_relationship%ROWTYPE;
    exist_c int;
    ccount  int;
    ecount  int;
    rtn     bigint;
BEGIN
    EXECUTE 'SELECT * FROM tmpcvtermpath p1, tmpcvtermpath p2 WHERE p1.subject_id=p2.object_id AND p1.object_id=p2.subject_id AND p1.object_id = '|| origin || ' AND p2.subject_id = ' || child_id || 'AND ' || depth || '> 0';
    GET DIAGNOSTICS ccount = ROW_COUNT;
    IF (ccount > 0) THEN
        --RAISE EXCEPTION 'FOUND CYCLE: node % on cycle path',origin;
        RETURN origin;
    END IF;
    EXECUTE 'SELECT * FROM tmpcvtermpath WHERE cv_id = ' || cvid || ' AND object_id = ' || origin || ' AND subject_id = ' || child_id || ' AND ' || origin || '<>' || child_id;
    GET DIAGNOSTICS ecount = ROW_COUNT;
    IF (ecount > 0) THEN
        --RAISE NOTICE 'FOUND TWICE (node), will check root obj % subj %',origin, child_id;
        SELECT INTO rtn _fill_cvtermpath4root2detect_cycle(child_id, cvid);
        IF (rtn > 0) THEN
            RETURN rtn;
        END IF;
    END IF;
    EXECUTE 'SELECT * FROM tmpcvtermpath WHERE cv_id = ' || cvid || ' AND object_id = ' || origin || ' AND subject_id = ' || child_id || ' AND pathdistance = ' || depth;
    GET DIAGNOSTICS exist_c = ROW_COUNT;
    IF (exist_c = 0) THEN
        EXECUTE 'INSERT INTO tmpcvtermpath (object_id, subject_id, cv_id, type_id, pathdistance) VALUES(' || origin || ', ' || child_id || ', ' || cvid || ', ' || typeid || ', ' || depth || ')';
    END IF;
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = child_id LOOP
        --RAISE NOTICE 'DOING for node, % %', origin, cterm.subject_id;
        SELECT INTO rtn _fill_cvtermpath4node2detect_cycle(origin, cterm.subject_id, cvid, cterm.type_id, depth+1);
        IF (rtn > 0) THEN
            RETURN rtn;
        END IF;
    END LOOP;
    RETURN 0;
END;
$_$;


ALTER FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) OWNER TO www;

--
-- Name: _fill_cvtermpath4root(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4root(bigint, bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rootid alias for $1;
    cvid alias for $2;
    ttype bigint;
    cterm cvterm_relationship%ROWTYPE;
    child cvterm_relationship%ROWTYPE;
BEGIN
    SELECT INTO ttype cvterm_id FROM cvterm WHERE (name = 'isa' OR name = 'is_a');
    PERFORM _fill_cvtermpath4node(rootid, rootid, cvid, ttype, 0);
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = rootid LOOP
        PERFORM _fill_cvtermpath4root(cterm.subject_id, cvid);
        -- RAISE NOTICE 'DONE for term, %', cterm.subject_id;
    END LOOP;
    RETURN 1;
END;
$_$;


ALTER FUNCTION chado._fill_cvtermpath4root(bigint, bigint) OWNER TO www;

--
-- Name: _fill_cvtermpath4root2detect_cycle(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rootid alias for $1;
    cvid alias for $2;
    ttype bigint;
    ccount int;
    cterm cvterm_relationship%ROWTYPE;
    child cvterm_relationship%ROWTYPE;
    rtn     bigint;
BEGIN
    SELECT INTO ttype cvterm_id FROM cvterm WHERE (name = 'isa' OR name = 'is_a');
    SELECT INTO rtn _fill_cvtermpath4node2detect_cycle(rootid, rootid, cvid, ttype, 0);
    IF (rtn > 0) THEN
        RETURN rtn;
    END IF;
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = rootid LOOP
        EXECUTE 'SELECT * FROM tmpcvtermpath p1, tmpcvtermpath p2 WHERE p1.subject_id=p2.object_id AND p1.object_id=p2.subject_id AND p1.object_id=' || rootid || ' AND p1.subject_id=' || cterm.subject_id;
        GET DIAGNOSTICS ccount = ROW_COUNT;
        IF (ccount > 0) THEN
            --RAISE NOTICE 'FOUND TWICE (root), will check root obj % subj %',rootid,cterm.subject_id;
            SELECT INTO rtn _fill_cvtermpath4node2detect_cycle(rootid, cterm.subject_id, cvid, ttype, 0);
            IF (rtn > 0) THEN
                RETURN rtn;
            END IF;
        ELSE
            SELECT INTO rtn _fill_cvtermpath4root2detect_cycle(cterm.subject_id, cvid);
            IF (rtn > 0) THEN
                RETURN rtn;
            END IF;
        END IF;
    END LOOP;
    RETURN 0;
END;
$_$;


ALTER FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) OWNER TO www;

--
-- Name: _fill_cvtermpath4soi(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4soi(integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rootid alias for $1;
    cvid alias for $2;
    ttype int;
    cterm soi_type%ROWTYPE;
BEGIN
    SELECT INTO ttype cvterm_id FROM cvterm WHERE name = 'isa';
    --RAISE NOTICE 'got ttype %',ttype;
    PERFORM _fill_cvtermpath4soinode(rootid, rootid, cvid, ttype, 0);
    FOR cterm IN SELECT tmp_type AS type_id, subject_id FROM tmpcvtr WHERE object_id = rootid LOOP
        PERFORM _fill_cvtermpath4soi(cterm.subject_id, cvid);
    END LOOP;
    RETURN 1;
END;   
$_$;


ALTER FUNCTION chado._fill_cvtermpath4soi(integer, integer) OWNER TO www;

--
-- Name: _fill_cvtermpath4soinode(integer, integer, integer, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    origin alias for $1;
    child_id alias for $2;
    cvid alias for $3;
    typeid alias for $4;
    depth alias for $5;
    cterm soi_type%ROWTYPE;
    exist_c int;
BEGIN
    --RAISE NOTICE 'depth=% o=%, root=%, cv=%, t=%', depth,origin,child_id,cvid,typeid;
    SELECT INTO exist_c count(*) FROM cvtermpath WHERE cv_id = cvid AND object_id = origin AND subject_id = child_id AND pathdistance = depth;
    --- longest path
    IF (exist_c > 0) THEN
        UPDATE cvtermpath SET pathdistance = depth WHERE cv_id = cvid AND object_id = origin AND subject_id = child_id;
    ELSE
        INSERT INTO cvtermpath (object_id, subject_id, cv_id, type_id, pathdistance) VALUES(origin, child_id, cvid, typeid, depth);
    END IF;
    FOR cterm IN SELECT tmp_type AS type_id, subject_id FROM tmpcvtr WHERE object_id = child_id LOOP
        PERFORM _fill_cvtermpath4soinode(origin, cterm.subject_id, cvid, cterm.type_id, depth+1);
    END LOOP;
    RETURN 1;
END;
$_$;


ALTER FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) OWNER TO www;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: cvtermpath; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvtermpath (
    cvtermpath_id bigint NOT NULL,
    type_id bigint,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    cv_id bigint NOT NULL,
    pathdistance integer
);


ALTER TABLE chado.cvtermpath OWNER TO www;

--
-- Name: TABLE cvtermpath; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvtermpath IS 'The reflexive transitive closure of
the cvterm_relationship relation.';


--
-- Name: COLUMN cvtermpath.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermpath.type_id IS 'The relationship type that
this is a closure over. If null, then this is a closure over ALL
relationship types. If non-null, then this references a relationship
cvterm - note that the closure will apply to both this relationship
AND the OBO_REL:is_a (subclass) relationship.';


--
-- Name: COLUMN cvtermpath.cv_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermpath.cv_id IS 'Closures will mostly be within
one cv. If the closure of a relationship traverses a cv, then this
refers to the cv of the object_id cvterm.';


--
-- Name: COLUMN cvtermpath.pathdistance; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermpath.pathdistance IS 'The number of steps
required to get from the subject cvterm to the object cvterm, counting
from zero (reflexive relationship).';


--
-- Name: _get_all_object_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._get_all_object_ids(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    leaf alias for $1;
    cterm cvtermpath%ROWTYPE;
    cterm2 cvtermpath%ROWTYPE;
BEGIN
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE subject_id = leaf LOOP
        RETURN NEXT cterm;
        FOR cterm2 IN SELECT * FROM _get_all_object_ids(cterm.object_id) LOOP
            RETURN NEXT cterm2;
        END LOOP;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado._get_all_object_ids(integer) OWNER TO www;

--
-- Name: _get_all_subject_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado._get_all_subject_ids(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    root alias for $1;
    cterm cvtermpath%ROWTYPE;
    cterm2 cvtermpath%ROWTYPE;
BEGIN
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = root LOOP
        RETURN NEXT cterm;
        FOR cterm2 IN SELECT * FROM _get_all_subject_ids(cterm.subject_id) LOOP
            RETURN NEXT cterm2;
        END LOOP;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado._get_all_subject_ids(integer) OWNER TO www;

--
-- Name: boxquery(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.boxquery(bigint, bigint) RETURNS box
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT box (create_point($1, $2), create_point($1, $2))$_$;


ALTER FUNCTION chado.boxquery(bigint, bigint) OWNER TO www;

--
-- Name: boxquery(bigint, bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.boxquery(bigint, bigint, bigint) RETURNS box
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT box (create_point($1, $2), create_point($1, $3))$_$;


ALTER FUNCTION chado.boxquery(bigint, bigint, bigint) OWNER TO www;

--
-- Name: boxrange(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.boxrange(bigint, bigint) RETURNS box
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT box (create_point(CAST(0 AS bigint), $1), create_point($2,500000000))$_$;


ALTER FUNCTION chado.boxrange(bigint, bigint) OWNER TO www;

--
-- Name: boxrange(bigint, bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.boxrange(bigint, bigint, bigint) RETURNS box
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT box (create_point($1, $2), create_point($1,$3))$_$;


ALTER FUNCTION chado.boxrange(bigint, bigint, bigint) OWNER TO www;

--
-- Name: complement_residues(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.complement_residues(text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT (translate($1, 
                   'acgtrymkswhbvdnxACGTRYMKSWHBVDNX',
                   'tgcayrkmswdvbhnxTGCAYRKMSWDVBHNX'))$_$;


ALTER FUNCTION chado.complement_residues(text) OWNER TO www;

--
-- Name: concat_pair(text, text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.concat_pair(text, text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT $1 || $2$_$;


ALTER FUNCTION chado.concat_pair(text, text) OWNER TO www;

--
-- Name: create_point(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.create_point(bigint, bigint) RETURNS point
    LANGUAGE sql
    AS $_$SELECT point ($1, $2)$_$;


ALTER FUNCTION chado.create_point(bigint, bigint) OWNER TO www;

--
-- Name: create_soi(); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.create_soi() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    parent soi_type%ROWTYPE;
    isa_id cvterm.cvterm_id%TYPE;
    soi_term TEXT := 'soi';
    soi_def TEXT := 'ontology of SO feature instantiated in database';
    soi_cvid bigint;
    soiterm_id bigint;
    pcount INTEGER;
    count INTEGER := 0;
    cquery TEXT;
BEGIN
    SELECT INTO isa_id cvterm_id FROM cvterm WHERE name = 'isa';
    SELECT INTO soi_cvid cv_id FROM cv WHERE name = soi_term;
    IF (soi_cvid > 0) THEN
        DELETE FROM cvtermpath WHERE cv_id = soi_cvid;
        DELETE FROM cvterm WHERE cv_id = soi_cvid;
    ELSE
        INSERT INTO cv (name, definition) VALUES(soi_term, soi_def);
    END IF;
    SELECT INTO soi_cvid cv_id FROM cv WHERE name = soi_term;
    INSERT INTO cvterm (name, cv_id) VALUES(soi_term, soi_cvid);
    SELECT INTO soiterm_id cvterm_id FROM cvterm WHERE name = soi_term;
    CREATE TEMP TABLE tmpcvtr (tmp_type INT, type_id bigint, subject_id bigint, object_id bigint);
    CREATE UNIQUE INDEX u_tmpcvtr ON tmpcvtr(subject_id, object_id);
    INSERT INTO tmpcvtr (tmp_type, type_id, subject_id, object_id)
        SELECT DISTINCT isa_id, soiterm_id, f.type_id, soiterm_id FROM feature f, cvterm t
        WHERE f.type_id = t.cvterm_id AND f.type_id > 0;
    EXECUTE 'select * from tmpcvtr where type_id = ' || soiterm_id || ';';
    get diagnostics pcount = row_count;
    raise notice 'all types in feature %',pcount;
    FOR parent IN SELECT DISTINCT 0, t.cvterm_id, 0 FROM feature c, feature_relationship fr, cvterm t
            WHERE t.cvterm_id = c.type_id AND c.feature_id = fr.subject_id LOOP
        DELETE FROM tmpcvtr WHERE type_id = soiterm_id and object_id = soiterm_id
            AND subject_id = parent.subject_id;
    END LOOP;
    EXECUTE 'select * from tmpcvtr where type_id = ' || soiterm_id || ';';
    get diagnostics pcount = row_count;
    raise notice 'all types in feature after delete child %',pcount;
    CREATE TEMP TABLE tmproot (cv_id bigint not null, cvterm_id bigint not null, status INTEGER DEFAULT 0);
    cquery := 'SELECT * FROM tmproot tmp WHERE tmp.status = 0;';
    INSERT INTO tmproot (cv_id, cvterm_id, status) SELECT DISTINCT soi_cvid, c.subject_id, 0 FROM tmpcvtr c
        WHERE c.object_id = soiterm_id;
    EXECUTE cquery;
    GET DIAGNOSTICS pcount = ROW_COUNT;
    WHILE (pcount > 0) LOOP
        RAISE NOTICE 'num child temp (to be inserted) in tmpcvtr: %',pcount;
        INSERT INTO tmpcvtr (tmp_type, type_id, subject_id, object_id)
            SELECT DISTINCT fr.type_id, soiterm_id, c.type_id, p.cvterm_id FROM feature c, feature_relationship fr,
            tmproot p, feature pf, cvterm t WHERE c.feature_id = fr.subject_id AND fr.object_id = pf.feature_id
            AND p.cvterm_id = pf.type_id AND t.cvterm_id = c.type_id AND p.status = 0;
        UPDATE tmproot SET status = 1 WHERE status = 0;
        INSERT INTO tmproot (cv_id, cvterm_id, status)
            SELECT DISTINCT soi_cvid, c.type_id, 0 FROM feature c, feature_relationship fr,
            tmproot tmp, feature p, cvterm t WHERE c.feature_id = fr.subject_id AND fr.object_id = p.feature_id
            AND tmp.cvterm_id = p.type_id AND t.cvterm_id = c.type_id AND tmp.status = 1;
        UPDATE tmproot SET status = 2 WHERE status = 1;
        EXECUTE cquery;
        GET DIAGNOSTICS pcount = ROW_COUNT; 
    END LOOP;
    DELETE FROM tmproot;
    PERFORM _fill_cvtermpath4soi(soiterm_id, soi_cvid);
    DROP TABLE tmpcvtr;
    DROP TABLE tmproot;
    RETURN 1;
END;
$$;


ALTER FUNCTION chado.create_soi() OWNER TO www;

--
-- Name: feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature (
    feature_id bigint NOT NULL,
    dbxref_id bigint,
    organism_id bigint NOT NULL,
    name character varying(255),
    uniquename text NOT NULL,
    residues text,
    seqlen bigint,
    md5checksum character(32),
    type_id bigint NOT NULL,
    is_analysis boolean DEFAULT false NOT NULL,
    is_obsolete boolean DEFAULT false NOT NULL,
    timeaccessioned timestamp without time zone DEFAULT now() NOT NULL,
    timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);
ALTER TABLE ONLY chado.feature ALTER COLUMN residues SET STORAGE EXTERNAL;


ALTER TABLE chado.feature OWNER TO www;

--
-- Name: TABLE feature; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature IS 'A feature is a biological sequence or a
section of a biological sequence, or a collection of such
sections. Examples include genes, exons, transcripts, regulatory
regions, polypeptides, protein domains, chromosome sequences, sequence
variations, cross-genome match regions such as hits and HSPs and so
on; see the Sequence Ontology for more. The combination of
organism_id, uniquename and type_id should be unique.';


--
-- Name: COLUMN feature.dbxref_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.dbxref_id IS 'An optional primary chado.stable
identifier for this feature. Secondary identifiers and external
dbxrefs go in the table feature_dbxref.';


--
-- Name: COLUMN feature.organism_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.organism_id IS 'The organism to which this feature
belongs. This column is mandatory.';


--
-- Name: COLUMN feature.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.name IS 'The optional human-readable common name for
a feature, for display purposes.';


--
-- Name: COLUMN feature.uniquename; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.uniquename IS 'The unique name for a feature; may
not be necessarily be particularly human-readable, although this is
preferred. This name must be unique for this type of feature within
this organism.';


--
-- Name: COLUMN feature.residues; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.residues IS 'A sequence of alphabetic characters
representing biological residues (nucleic acids, amino acids). This
column does not need to be manifested for all features; it is optional
for features such as exons where the residues can be derived from the
featureloc. It is recommended that the value for this column be
manifested for features which may may non-contiguous sublocations (e.g.
transcripts), since derivation at query time is non-trivial. For
expressed sequence, the DNA sequence should be used rather than the
RNA sequence. The default storage method for the residues column is
EXTERNAL, which will store it uncompressed to make substring operations
faster.';


--
-- Name: COLUMN feature.seqlen; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.seqlen IS 'The length of the residue feature. See
column:residues. This column is partially redundant with the residues
column, and also with featureloc. This column is required because the
location may be unknown and the residue sequence may not be
manifested, yet it may be desirable to store and query the length of
the feature. The seqlen should always be manifested where the length
of the sequence is known.';


--
-- Name: COLUMN feature.md5checksum; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.md5checksum IS 'The 32-character checksum of the sequence,
calculated using the MD5 algorithm. This is practically guaranteed to
be unique for any feature. This column thus acts as a unique
identifier on the mathematical sequence.';


--
-- Name: COLUMN feature.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.type_id IS 'A required reference to a table:cvterm
giving the feature type. This will typically be a Sequence Ontology
identifier. This column is thus used to subclass the feature table.';


--
-- Name: COLUMN feature.is_analysis; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.is_analysis IS 'Boolean indicating whether this
feature is annotated or the result of an automated analysis. Analysis
results also use the companalysis module. Note that the dividing line
between analysis and annotation may be fuzzy, this should be determined on
a per-project basis in a consistent manner. One requirement is that
there should only be one non-analysis version of each wild-type gene
feature in a genome, whereas the same gene feature can be predicted
multiple times in different analyses.';


--
-- Name: COLUMN feature.is_obsolete; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.is_obsolete IS 'Boolean indicating whether this
feature has been obsoleted. Some chado instances may choose to simply
remove the feature altogether, others may choose to keep an obsolete
row in the table.';


--
-- Name: COLUMN feature.timeaccessioned; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.timeaccessioned IS 'For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.';


--
-- Name: COLUMN feature.timelastmodified; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature.timelastmodified IS 'For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.';


--
-- Name: feature_disjoint_from(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.feature_disjoint_from(bigint) RETURNS SETOF chado.feature
    LANGUAGE sql
    AS $_$SELECT feature.*
  FROM feature
   INNER JOIN featureloc AS x ON (x.feature_id=feature.feature_id)
   INNER JOIN featureloc AS y ON (y.feature_id = $1)
  WHERE
   x.srcfeature_id = y.srcfeature_id            AND
   ( x.fmax < y.fmin OR x.fmin > y.fmax ) $_$;


ALTER FUNCTION chado.feature_disjoint_from(bigint) OWNER TO www;

--
-- Name: feature_overlaps(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.feature_overlaps(bigint) RETURNS SETOF chado.feature
    LANGUAGE sql
    AS $_$SELECT feature.*
  FROM feature
   INNER JOIN featureloc AS x ON (x.feature_id=feature.feature_id)
   INNER JOIN featureloc AS y ON (y.feature_id = $1)
  WHERE
   x.srcfeature_id = y.srcfeature_id            AND
   ( x.fmax >= y.fmin AND x.fmin <= y.fmax ) $_$;


ALTER FUNCTION chado.feature_overlaps(bigint) OWNER TO www;

--
-- Name: featureloc; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featureloc (
    featureloc_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    srcfeature_id bigint,
    fmin bigint,
    is_fmin_partial boolean DEFAULT false NOT NULL,
    fmax bigint,
    is_fmax_partial boolean DEFAULT false NOT NULL,
    strand smallint,
    phase integer,
    residue_info text,
    locgroup integer DEFAULT 0 NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    CONSTRAINT featureloc_c2 CHECK ((fmin <= fmax))
);


ALTER TABLE chado.featureloc OWNER TO www;

--
-- Name: TABLE featureloc; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featureloc IS 'The location of a feature relative to
another feature. Important: interbase coordinates are used. This is
vital as it allows us to represent zero-length features e.g. splice
sites, insertion points without an awkward fuzzy system. Features
typically have exactly ONE location, but this need not be the
case. Some features may not be localized (e.g. a gene that has been
characterized genetically but no sequence or molecular information is
available). Note on multiple locations: Each feature can have 0 or
more locations. Multiple locations do NOT indicate non-contiguous
locations (if a feature such as a transcript has a non-contiguous
location, then the subfeatures such as exons should always be
manifested). Instead, multiple featurelocs for a feature designate
alternate locations or grouped locations; for instance, a feature
designating a blast hit or hsp will have two locations, one on the
query feature, one on the subject feature. Features representing
sequence variation could have alternate locations instantiated on a
feature on the mutant strain. The column:rank is used to
differentiate these different locations. Reflexive locations should
never be stored - this is for -proper- (i.e. non-self) locations only; nothing should be located relative to itself.';


--
-- Name: COLUMN featureloc.feature_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.feature_id IS 'The feature that is being located. Any feature can have zero or more featurelocs.';


--
-- Name: COLUMN featureloc.srcfeature_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.srcfeature_id IS 'The source feature which this location is relative to. Every location is relative to another feature (however, this column is nullable, because the srcfeature may not be known). All locations are -proper- that is, nothing should be located relative to itself. No cycles are allowed in the featureloc graph.';


--
-- Name: COLUMN featureloc.fmin; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.fmin IS 'The leftmost/minimal boundary in the linear range represented by the featureloc. Sometimes (e.g. in Bioperl) this is called -start- although this is confusing because it does not necessarily represent the 5-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. To convert this to the leftmost position in a base-oriented system (eg GFF, Bioperl), add 1 to fmin.';


--
-- Name: COLUMN featureloc.is_fmin_partial; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.is_fmin_partial IS 'This is typically
false, but may be true if the value for column:fmin is inaccurate or
the leftmost part of the range is unknown/unbounded.';


--
-- Name: COLUMN featureloc.fmax; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.fmax IS 'The rightmost/maximal boundary in the linear range represented by the featureloc. Sometimes (e.g. in bioperl) this is called -end- although this is confusing because it does not necessarily represent the 3-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. No conversion is required to go from fmax to the rightmost coordinate in a base-oriented system that counts from 1 (e.g. GFF, Bioperl).';


--
-- Name: COLUMN featureloc.is_fmax_partial; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.is_fmax_partial IS 'This is typically
false, but may be true if the value for column:fmax is inaccurate or
the rightmost part of the range is unknown/unbounded.';


--
-- Name: COLUMN featureloc.strand; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.strand IS 'The orientation/directionality of the
location. Should be 0, -1 or +1.';


--
-- Name: COLUMN featureloc.phase; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.phase IS 'Phase of translation with
respect to srcfeature_id.
Values are 0, 1, 2. It may not be possible to manifest this column for
some features such as exons, because the phase is dependant on the
spliceform (the same exon can appear in multiple spliceforms). This column is mostly useful for predicted exons and CDSs.';


--
-- Name: COLUMN featureloc.residue_info; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.residue_info IS 'Alternative residues,
when these differ from feature.residues. For instance, a SNP feature
located on a wild and mutant protein would have different alternative residues.
for alignment/similarity features, the alternative residues is used to
represent the alignment string (CIGAR format). Note on variation
features; even if we do not want to instantiate a mutant
chromosome/contig feature, we can still represent a SNP etc with 2
locations, one (rank 0) on the genome, the other (rank 1) would have
most fields null, except for alternative residues.';


--
-- Name: COLUMN featureloc.locgroup; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.locgroup IS 'This is used to manifest redundant,
derivable extra locations for a feature. The default locgroup=0 is
used for the DIRECT location of a feature. Important: most Chado users may
never use featurelocs WITH logroup > 0. Transitively derived locations
are indicated with locgroup > 0. For example, the position of an exon on
a BAC and in global chromosome coordinates. This column is used to
differentiate these groupings of locations. The default locgroup 0
is used for the main or primary location, from which the others can be
derived via coordinate transformations. Another example of redundant
locations is storing ORF coordinates relative to both transcript and
genome. Redundant locations open the possibility of the database
getting into inconsistent states; this schema gives us the flexibility
of both warehouse instantiations with redundant locations (easier for
querying) and management instantiations with no redundant
locations. An example of using both locgroup and rank: imagine a
feature indicating a conserved region between the chromosomes of two
different species. We may want to keep redundant locations on both
contigs and chromosomes. We would thus have 4 locations for the single
conserved region feature - two distinct locgroups (contig level and
chromosome level) and two distinct ranks (for the two species).';


--
-- Name: COLUMN featureloc.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureloc.rank IS 'Used when a feature has >1
location, otherwise the default rank 0 is used. Some features (e.g.
blast hits and HSPs) have two locations - one on the query and one on
the subject. Rank is used to differentiate these. Rank=0 is always
used for the query, Rank=1 for the subject. For multiple alignments,
assignment of rank is arbitrary. Rank is also used for
sequence_variant features, such as SNPs. Rank=0 indicates the wildtype
(or baseline) feature, Rank=1 indicates the mutant (or compared) feature.';


--
-- Name: feature_subalignments(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.feature_subalignments(integer) RETURNS SETOF chado.featureloc
    LANGUAGE plpgsql
    AS $_$
DECLARE
  return_data featureloc%ROWTYPE;
  f_id ALIAS FOR $1;
  feature_data feature%rowtype;
  featureloc_data featureloc%rowtype;
  s text;
  fmin integer;
  slen integer;
BEGIN
  --RAISE NOTICE 'feature_id is %', featureloc_data.feature_id;
  SELECT INTO feature_data * FROM feature WHERE feature_id = f_id;
  FOR featureloc_data IN SELECT * FROM featureloc WHERE feature_id = f_id LOOP
    --RAISE NOTICE 'fmin is %', featureloc_data.fmin;
    return_data.feature_id      = f_id;
    return_data.srcfeature_id   = featureloc_data.srcfeature_id;
    return_data.is_fmin_partial = featureloc_data.is_fmin_partial;
    return_data.is_fmax_partial = featureloc_data.is_fmax_partial;
    return_data.strand          = featureloc_data.strand;
    return_data.phase           = featureloc_data.phase;
    return_data.residue_info    = featureloc_data.residue_info;
    return_data.locgroup        = featureloc_data.locgroup;
    return_data.rank            = featureloc_data.rank;
    s = feature_data.residues;
    fmin = featureloc_data.fmin;
    slen = char_length(s);
    WHILE char_length(s) LOOP
      --RAISE NOTICE 'residues is %', s;
      --trim off leading match
      s = trim(leading '|ATCGNatcgn' from s);
      --if leading match detected
      IF slen > char_length(s) THEN
        return_data.fmin = fmin;
        return_data.fmax = featureloc_data.fmin + (slen - char_length(s));
        --if the string started with a match, return it,
        --otherwise, trim the gaps first (ie do not return this iteration)
        RETURN NEXT return_data;
      END IF;
      --trim off leading gap
      s = trim(leading '-' from s);
      fmin = featureloc_data.fmin + (slen - char_length(s));
    END LOOP;
  END LOOP;
  RETURN;
END;
$_$;


ALTER FUNCTION chado.feature_subalignments(integer) OWNER TO www;

--
-- Name: featureloc_slice(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.featureloc_slice(bigint, bigint) RETURNS SETOF chado.featureloc
    LANGUAGE sql
    AS $_$SELECT * from featureloc where boxquery($1, $2) @ boxrange(fmin,fmax)$_$;


ALTER FUNCTION chado.featureloc_slice(bigint, bigint) OWNER TO www;

--
-- Name: featureloc_slice(integer, bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.featureloc_slice(integer, bigint, bigint) RETURNS SETOF chado.featureloc
    LANGUAGE sql
    AS $_$SELECT * 
   FROM featureloc 
   WHERE boxquery($2, $3) @ boxrange(fmin,fmax)
   AND srcfeature_id = $1 $_$;


ALTER FUNCTION chado.featureloc_slice(integer, bigint, bigint) OWNER TO www;

--
-- Name: featureloc_slice(bigint, bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.featureloc_slice(bigint, bigint, bigint) RETURNS SETOF chado.featureloc
    LANGUAGE sql
    AS $_$SELECT * 
   FROM featureloc 
   WHERE boxquery($1, $2, $3) && boxrange(srcfeature_id,fmin,fmax)$_$;


ALTER FUNCTION chado.featureloc_slice(bigint, bigint, bigint) OWNER TO www;

--
-- Name: featureloc_slice(character varying, bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.featureloc_slice(character varying, bigint, bigint) RETURNS SETOF chado.featureloc
    LANGUAGE sql
    AS $_$SELECT featureloc.* 
   FROM featureloc 
   INNER JOIN feature AS srcf ON (srcf.feature_id = featureloc.srcfeature_id)
   WHERE boxquery($2, $3) @ boxrange(fmin,fmax)
   AND srcf.name = $1 $_$;


ALTER FUNCTION chado.featureloc_slice(character varying, bigint, bigint) OWNER TO www;

--
-- Name: featureslice(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.featureslice(integer, integer) RETURNS SETOF chado.featureloc
    LANGUAGE sql
    AS $_$SELECT * from featureloc where boxquery($1, $2) @ boxrange(fmin,fmax)$_$;


ALTER FUNCTION chado.featureslice(integer, integer) OWNER TO www;

--
-- Name: fill_cvtermpath(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.fill_cvtermpath(bigint) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvid alias for $1;
    root cvterm%ROWTYPE;
BEGIN
    DELETE FROM cvtermpath WHERE cv_id = cvid;
    FOR root IN SELECT DISTINCT t.* from cvterm t LEFT JOIN cvterm_relationship r ON (t.cvterm_id = r.subject_id) INNER JOIN cvterm_relationship r2 ON (t.cvterm_id = r2.object_id) WHERE t.cv_id = cvid AND r.subject_id is null LOOP
        PERFORM _fill_cvtermpath4root(root.cvterm_id, root.cv_id);
    END LOOP;
    RETURN 1;
END;   
$_$;


ALTER FUNCTION chado.fill_cvtermpath(bigint) OWNER TO www;

--
-- Name: fill_cvtermpath(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.fill_cvtermpath(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvname alias for $1;
    cv_id   int;
    rtn     int;
BEGIN
    SELECT INTO cv_id cv.cv_id from cv WHERE cv.name = cvname;
    SELECT INTO rtn fill_cvtermpath(cv_id);
    RETURN rtn;
END;   
$_$;


ALTER FUNCTION chado.fill_cvtermpath(character varying) OWNER TO www;

--
-- Name: get_all_object_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_all_object_ids(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    leaf alias for $1;
    cterm cvtermpath%ROWTYPE;
    exist_c int;
BEGIN
    SELECT INTO exist_c count(*) FROM cvtermpath WHERE object_id = leaf and pathdistance <= 0;
    IF (exist_c > 0) THEN
        FOR cterm IN SELECT * FROM cvtermpath WHERE subject_id = leaf AND pathdistance > 0 LOOP
            RETURN NEXT cterm;
        END LOOP;
    ELSE
        FOR cterm IN SELECT * FROM _get_all_object_ids(leaf) LOOP
            RETURN NEXT cterm;
        END LOOP;
    END IF;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_all_object_ids(integer) OWNER TO www;

--
-- Name: get_all_subject_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_all_subject_ids(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    root alias for $1;
    cterm cvtermpath%ROWTYPE;
    exist_c int;
BEGIN
    SELECT INTO exist_c count(*) FROM cvtermpath WHERE object_id = root and pathdistance <= 0;
    IF (exist_c > 0) THEN
        FOR cterm IN SELECT * FROM cvtermpath WHERE object_id = root and pathdistance > 0 LOOP
            RETURN NEXT cterm;
        END LOOP;
    ELSE
        FOR cterm IN SELECT * FROM _get_all_subject_ids(root) LOOP
            RETURN NEXT cterm;
        END LOOP;
    END IF;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_all_subject_ids(integer) OWNER TO www;

--
-- Name: get_cv_id_for_feature(); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cv_id_for_feature() RETURNS bigint
    LANGUAGE sql
    AS $$SELECT cv_id FROM cv WHERE name='sequence'$$;


ALTER FUNCTION chado.get_cv_id_for_feature() OWNER TO www;

--
-- Name: get_cv_id_for_feature_relationsgip(); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cv_id_for_feature_relationsgip() RETURNS bigint
    LANGUAGE sql
    AS $$SELECT cv_id FROM cv WHERE name='relationship'$$;


ALTER FUNCTION chado.get_cv_id_for_feature_relationsgip() OWNER TO www;

--
-- Name: get_cv_id_for_featureprop(); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cv_id_for_featureprop() RETURNS bigint
    LANGUAGE sql
    AS $$SELECT cv_id FROM cv WHERE name='feature_property'$$;


ALTER FUNCTION chado.get_cv_id_for_featureprop() OWNER TO www;

--
-- Name: get_cycle_cvterm_id(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cycle_cvterm_id(integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvid alias for $1;
    root cvterm%ROWTYPE;
    rtn     int;
BEGIN
    CREATE TEMP TABLE tmpcvtermpath(object_id bigint, subject_id bigint, cv_id bigint, type_id bigint, pathdistance int);
    CREATE INDEX tmp_cvtpath1 ON tmpcvtermpath(object_id, subject_id);
    FOR root IN SELECT DISTINCT t.* from cvterm t LEFT JOIN cvterm_relationship r ON (t.cvterm_id = r.subject_id) INNER JOIN cvterm_relationship r2 ON (t.cvterm_id = r2.object_id) WHERE t.cv_id = cvid AND r.subject_id is null LOOP
        SELECT INTO rtn _fill_cvtermpath4root2detect_cycle(root.cvterm_id, root.cv_id);
        IF (rtn > 0) THEN
            DROP TABLE tmpcvtermpath;
            RETURN rtn;
        END IF;
    END LOOP;
    DROP TABLE tmpcvtermpath;
    RETURN 0;
END;   
$_$;


ALTER FUNCTION chado.get_cycle_cvterm_id(integer) OWNER TO www;

--
-- Name: get_cycle_cvterm_id(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cycle_cvterm_id(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvname alias for $1;
    cv_id bigint;
    rtn int;
BEGIN
    SELECT INTO cv_id cv.cv_id from cv WHERE cv.name = cvname;
    SELECT INTO rtn  get_cycle_cvterm_id(cv_id);
    RETURN rtn;
END;   
$_$;


ALTER FUNCTION chado.get_cycle_cvterm_id(character varying) OWNER TO www;

--
-- Name: get_cycle_cvterm_id(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cycle_cvterm_id(integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvid alias for $1;
    rootid alias for $2;
    rtn     int;
BEGIN
    CREATE TEMP TABLE tmpcvtermpath(object_id bigint, subject_id bigint, cv_id bigint, type_id bigint, pathdistance int);
    CREATE INDEX tmp_cvtpath1 ON tmpcvtermpath(object_id, subject_id);
    SELECT INTO rtn _fill_cvtermpath4root2detect_cycle(rootid, cvid);
    IF (rtn > 0) THEN
        DROP TABLE tmpcvtermpath;
        RETURN rtn;
    END IF;
    DROP TABLE tmpcvtermpath;
    RETURN 0;
END;   
$_$;


ALTER FUNCTION chado.get_cycle_cvterm_id(integer, integer) OWNER TO www;

--
-- Name: get_cycle_cvterm_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_cycle_cvterm_ids(integer) RETURNS SETOF integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    cvid alias for $1;
    root cvterm%ROWTYPE;
    rtn     int;
BEGIN
    FOR root IN SELECT DISTINCT t.* from cvterm t WHERE cv_id = cvid LOOP
        SELECT INTO rtn get_cycle_cvterm_id(cvid,root.cvterm_id);
        IF (rtn > 0) THEN
            RETURN NEXT rtn;
        END IF;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_cycle_cvterm_ids(integer) OWNER TO www;

--
-- Name: get_feature_id(character varying, character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_id(character varying, character varying, character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
  SELECT feature_id 
  FROM feature
  WHERE uniquename=$1
    AND type_id=get_feature_type_id($2)
    AND organism_id=get_organism_id($3)
 $_$;


ALTER FUNCTION chado.get_feature_id(character varying, character varying, character varying) OWNER TO www;

--
-- Name: get_feature_ids(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids(text) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    sql alias for $1;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
    myrc3 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN EXECUTE sql LOOP
        RETURN NEXT myrc;
        FOR myrc2 IN SELECT * FROM get_up_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc2;
        END LOOP;
        FOR myrc3 IN SELECT * FROM get_sub_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc3;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids(text) OWNER TO www;

--
-- Name: get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    ptype alias for $1;
    ctype alias for $2;
    ccount alias for $3;
    operator alias for $4;
    is_an alias for $5;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type %ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT f.feature_id
        FROM feature f INNER join (select count(*) as c, p.feature_id FROM feature p
        INNER join cvterm pt ON (p.type_id = pt.cvterm_id) INNER join feature_relationship fr
        ON (p.feature_id = fr.object_id) INNER join feature c ON (c.feature_id = fr.subject_id)
        INNER join cvterm ct ON (c.type_id = ct.cvterm_id)
        WHERE pt.name = ' || quote_literal(ptype) || ' AND ct.name = ' || quote_literal(ctype)
        || ' AND p.is_analysis = ' || quote_literal(is_an) || ' group by p.feature_id) as cq
        ON (cq.feature_id = f.feature_id) WHERE cq.c ' || operator || ccount || ';';
    ---RAISE NOTICE '%', query; 
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) OWNER TO www;

--
-- Name: get_feature_ids_by_ont(character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    aspect alias for $1;
    term alias for $2;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT fcvt.feature_id 
        FROM feature_cvterm fcvt, cv, cvterm t WHERE cv.cv_id = t.cv_id AND
        t.cvterm_id = fcvt.cvterm_id AND cv.name = ' || quote_literal(aspect) ||
        ' AND t.name = ' || quote_literal(term) || ';';
    IF (STRPOS(term, '%') > 0) THEN
        query := 'SELECT DISTINCT fcvt.feature_id 
            FROM feature_cvterm fcvt, cv, cvterm t WHERE cv.cv_id = t.cv_id AND
            t.cvterm_id = fcvt.cvterm_id AND cv.name = ' || quote_literal(aspect) ||
            ' AND t.name like ' || quote_literal(term) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) OWNER TO www;

--
-- Name: get_feature_ids_by_ont_root(character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    aspect alias for $1;
    term alias for $2;
    query TEXT;
    subquery TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    subquery := 'SELECT t.cvterm_id FROM cv, cvterm t WHERE cv.cv_id = t.cv_id 
        AND cv.name = ' || quote_literal(aspect) || ' AND t.name = ' || quote_literal(term) || ';';
    IF (STRPOS(term, '%') > 0) THEN
        subquery := 'SELECT t.cvterm_id FROM cv, cvterm t WHERE cv.cv_id = t.cv_id 
            AND cv.name = ' || quote_literal(aspect) || ' AND t.name like ' || quote_literal(term) || ';';
    END IF;
    query := 'SELECT DISTINCT fcvt.feature_id 
        FROM feature_cvterm fcvt INNER JOIN (SELECT cvterm_id FROM get_it_sub_cvterm_ids(' || quote_literal(subquery) || ')) AS ont ON (fcvt.cvterm_id = ont.cvterm_id);';
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) OWNER TO www;

--
-- Name: get_feature_ids_by_property(character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_property(character varying, character varying) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_type alias for $1;
    p_val alias for $2;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT fprop.feature_id 
        FROM featureprop fprop, cvterm t WHERE t.cvterm_id = fprop.type_id AND t.name = ' ||
        quote_literal(p_type) || ' AND fprop.value = ' || quote_literal(p_val) || ';';
    IF (STRPOS(p_val, '%') > 0) THEN
        query := 'SELECT DISTINCT fprop.feature_id 
            FROM featureprop fprop, cvterm t WHERE t.cvterm_id = fprop.type_id AND t.name = ' ||
            quote_literal(p_type) || ' AND fprop.value like ' || quote_literal(p_val) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_property(character varying, character varying) OWNER TO www;

--
-- Name: get_feature_ids_by_propval(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_propval(character varying) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    p_val alias for $1;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT fprop.feature_id 
        FROM featureprop fprop WHERE fprop.value = ' || quote_literal(p_val) || ';';
    IF (STRPOS(p_val, '%') > 0) THEN
        query := 'SELECT DISTINCT fprop.feature_id 
            FROM featureprop fprop WHERE fprop.value like ' || quote_literal(p_val) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_propval(character varying) OWNER TO www;

--
-- Name: get_feature_ids_by_type(character varying, character); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_type(character varying, character) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    gtype alias for $1;
    is_an alias for $2;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT f.feature_id 
        FROM feature f, cvterm t WHERE t.cvterm_id = f.type_id AND t.name = ' || quote_literal(gtype) ||
        ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    IF (STRPOS(gtype, '%') > 0) THEN
        query := 'SELECT DISTINCT f.feature_id 
            FROM feature f, cvterm t WHERE t.cvterm_id = f.type_id AND t.name like '
            || quote_literal(gtype) || ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_type(character varying, character) OWNER TO www;

--
-- Name: get_feature_ids_by_type_name(character varying, text, character); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    gtype alias for $1;
    name alias for $2;
    is_an alias for $3;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT f.feature_id 
        FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id)
        WHERE t.name = ' || quote_literal(gtype) || ' AND (f.uniquename = ' || quote_literal(name)
        || ' OR f.name = ' || quote_literal(name) || ') AND f.is_analysis = ' || quote_literal(is_an) || ';';
    IF (STRPOS(name, '%') > 0) THEN
        query := 'SELECT DISTINCT f.feature_id 
            FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id)
            WHERE t.name = ' || quote_literal(gtype) || ' AND (f.uniquename like ' || quote_literal(name)
            || ' OR f.name like ' || quote_literal(name) || ') AND f.is_analysis = ' || quote_literal(is_an) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) OWNER TO www;

--
-- Name: get_feature_ids_by_type_src(character varying, text, character); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    gtype alias for $1;
    src alias for $2;
    is_an alias for $3;
    query TEXT;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT f.feature_id 
        FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id) INNER join featureloc fl
        ON (f.feature_id = fl.feature_id) INNER join feature src ON (src.feature_id = fl.srcfeature_id)
        WHERE t.name = ' || quote_literal(gtype) || ' AND src.uniquename = ' || quote_literal(src)
        || ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    IF (STRPOS(gtype, '%') > 0) THEN
        query := 'SELECT DISTINCT f.feature_id 
            FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id) INNER join featureloc fl
            ON (f.feature_id = fl.feature_id) INNER join feature src ON (src.feature_id = fl.srcfeature_id)
            WHERE t.name like ' || quote_literal(gtype) || ' AND src.uniquename = ' || quote_literal(src)
            || ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) OWNER TO www;

--
-- Name: get_feature_relationship_type_id(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_relationship_type_id(character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
  SELECT cvterm_id 
  FROM cv INNER JOIN cvterm USING (cv_id)
  WHERE cvterm.name=$1 AND cv.name='relationship'
 $_$;


ALTER FUNCTION chado.get_feature_relationship_type_id(character varying) OWNER TO www;

--
-- Name: get_feature_type_id(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_feature_type_id(character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$ 
  SELECT cvterm_id 
  FROM cv INNER JOIN cvterm USING (cv_id)
  WHERE cvterm.name=$1 AND cv.name='sequence'
 $_$;


ALTER FUNCTION chado.get_feature_type_id(character varying) OWNER TO www;

--
-- Name: get_featureprop_type_id(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_featureprop_type_id(character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
  SELECT cvterm_id 
  FROM cv INNER JOIN cvterm USING (cv_id)
  WHERE cvterm.name=$1 AND cv.name='feature_property'
 $_$;


ALTER FUNCTION chado.get_featureprop_type_id(character varying) OWNER TO www;

--
-- Name: get_graph_above(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_graph_above(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    leaf alias for $1;
    cterm cvtermpath%ROWTYPE;
    cterm2 cvtermpath%ROWTYPE;
BEGIN
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE subject_id = leaf LOOP
        RETURN NEXT cterm;
        FOR cterm2 IN SELECT * FROM get_all_object_ids(cterm.object_id) LOOP
            RETURN NEXT cterm2;
        END LOOP;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_graph_above(integer) OWNER TO www;

--
-- Name: get_graph_below(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_graph_below(integer) RETURNS SETOF chado.cvtermpath
    LANGUAGE plpgsql
    AS $_$
DECLARE
    root alias for $1;
    cterm cvtermpath%ROWTYPE;
    cterm2 cvtermpath%ROWTYPE;
BEGIN
    FOR cterm IN SELECT * FROM cvterm_relationship WHERE object_id = root LOOP
        RETURN NEXT cterm;
        FOR cterm2 IN SELECT * FROM get_all_subject_ids(cterm.subject_id) LOOP
            RETURN NEXT cterm2;
        END LOOP;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_graph_below(integer) OWNER TO www;

--
-- Name: cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvterm (
    cvterm_id bigint NOT NULL,
    cv_id bigint NOT NULL,
    name character varying(1024) NOT NULL,
    definition text,
    dbxref_id bigint NOT NULL,
    is_obsolete integer DEFAULT 0 NOT NULL,
    is_relationshiptype integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cvterm OWNER TO www;

--
-- Name: TABLE cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvterm IS 'A term, class, universal or type within an
ontology or controlled vocabulary.  This table is also used for
relations and properties. cvterms constitute nodes in the graph
defined by the collection of cvterms and cvterm_relationships.';


--
-- Name: COLUMN cvterm.cv_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.cv_id IS 'The cv or ontology or namespace to which
this cvterm belongs.';


--
-- Name: COLUMN cvterm.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.name IS 'A concise human-readable name or
label for the cvterm. Uniquely identifies a cvterm within a cv.';


--
-- Name: COLUMN cvterm.definition; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.definition IS 'A human-readable text
definition.';


--
-- Name: COLUMN cvterm.dbxref_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.dbxref_id IS 'Primary identifier dbxref - The
unique global OBO identifier for this cvterm.  Note that a cvterm may
have multiple secondary dbxrefs - see also table: cvterm_dbxref.';


--
-- Name: COLUMN cvterm.is_obsolete; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.is_obsolete IS 'Boolean 0=false,1=true; see
GO documentation for details of obsoletion. Note that two terms with
different primary dbxrefs may exist if one is obsolete.';


--
-- Name: COLUMN cvterm.is_relationshiptype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm.is_relationshiptype IS 'Boolean
0=false,1=true relations or relationship types (also known as Typedefs
in OBO format, or as properties or slots) form a cv/ontology in
themselves. We use this flag to indicate whether this cvterm is an
actual term/class/universal or a relation. Relations may be drawn from
the OBO Relations ontology, but are not exclusively drawn from there.';


--
-- Name: get_it_sub_cvterm_ids(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_it_sub_cvterm_ids(text) RETURNS SETOF chado.cvterm
    LANGUAGE plpgsql
    AS $_$
DECLARE
    query alias for $1;
    cterm cvterm%ROWTYPE;
    cterm2 cvterm%ROWTYPE;
BEGIN
    FOR cterm IN EXECUTE query LOOP
        RETURN NEXT cterm;
        FOR cterm2 IN SELECT subject_id as cvterm_id FROM get_all_subject_ids(cterm.cvterm_id) LOOP
            RETURN NEXT cterm2;
        END LOOP;
    END LOOP;
    RETURN;
END;   
$_$;


ALTER FUNCTION chado.get_it_sub_cvterm_ids(text) OWNER TO www;

--
-- Name: get_organism_id(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_organism_id(character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$ 
SELECT organism_id
  FROM organism
  WHERE genus=substring($1,1,position(' ' IN $1)-1)
    AND species=substring($1,position(' ' IN $1)+1)
 $_$;


ALTER FUNCTION chado.get_organism_id(character varying) OWNER TO www;

--
-- Name: get_organism_id(character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_organism_id(character varying, character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
  SELECT organism_id 
  FROM organism
  WHERE genus=$1
    AND species=$2
 $_$;


ALTER FUNCTION chado.get_organism_id(character varying, character varying) OWNER TO www;

--
-- Name: get_organism_id_abbrev(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_organism_id_abbrev(character varying) RETURNS bigint
    LANGUAGE sql
    AS $_$
SELECT organism_id
  FROM organism
  WHERE substr(genus,1,1)=substring($1,1,1)
    AND species=substring($1,position(' ' IN $1)+1)
 $_$;


ALTER FUNCTION chado.get_organism_id_abbrev(character varying) OWNER TO www;

--
-- Name: get_sub_feature_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_sub_feature_ids(integer) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    root alias for $1;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN SELECT DISTINCT subject_id AS feature_id FROM feature_relationship WHERE object_id = root LOOP
        RETURN NEXT myrc;
        FOR myrc2 IN SELECT * FROM get_sub_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_sub_feature_ids(integer) OWNER TO www;

--
-- Name: get_sub_feature_ids(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_sub_feature_ids(text) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    sql alias for $1;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN EXECUTE sql LOOP
        FOR myrc2 IN SELECT * FROM get_sub_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_sub_feature_ids(text) OWNER TO www;

--
-- Name: get_sub_feature_ids(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_sub_feature_ids(integer, integer) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    root alias for $1;
    depth alias for $2;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN SELECT DISTINCT subject_id AS feature_id, depth FROM feature_relationship WHERE object_id = root LOOP
        RETURN NEXT myrc;
        FOR myrc2 IN SELECT * FROM get_sub_feature_ids(myrc.feature_id,depth+1) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_sub_feature_ids(integer, integer) OWNER TO www;

--
-- Name: get_sub_feature_ids_by_type_src(character varying, text, character); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    gtype alias for $1;
    src alias for $2;
    is_an alias for $3;
    query text;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    query := 'SELECT DISTINCT f.feature_id FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id)
        INNER join featureloc fl
        ON (f.feature_id = fl.feature_id) INNER join feature src ON (src.feature_id = fl.srcfeature_id)
        WHERE t.name = ' || quote_literal(gtype) || ' AND src.uniquename = ' || quote_literal(src)
        || ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    IF (STRPOS(gtype, '%') > 0) THEN
        query := 'SELECT DISTINCT f.feature_id FROM feature f INNER join cvterm t ON (f.type_id = t.cvterm_id)
             INNER join featureloc fl
            ON (f.feature_id = fl.feature_id) INNER join feature src ON (src.feature_id = fl.srcfeature_id)
            WHERE t.name like ' || quote_literal(gtype) || ' AND src.uniquename = ' || quote_literal(src)
            || ' AND f.is_analysis = ' || quote_literal(is_an) || ';';
    END IF;
    FOR myrc IN SELECT * FROM get_sub_feature_ids(query) LOOP
        RETURN NEXT myrc;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) OWNER TO www;

--
-- Name: get_up_feature_ids(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_up_feature_ids(integer) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    leaf alias for $1;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN SELECT DISTINCT object_id AS feature_id FROM feature_relationship WHERE subject_id = leaf LOOP
        RETURN NEXT myrc;
        FOR myrc2 IN SELECT * FROM get_up_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_up_feature_ids(integer) OWNER TO www;

--
-- Name: get_up_feature_ids(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_up_feature_ids(text) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    sql alias for $1;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN EXECUTE sql LOOP
        FOR myrc2 IN SELECT * FROM get_up_feature_ids(myrc.feature_id) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_up_feature_ids(text) OWNER TO www;

--
-- Name: get_up_feature_ids(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.get_up_feature_ids(integer, integer) RETURNS SETOF chado.feature_by_fx_type
    LANGUAGE plpgsql
    AS $_$
DECLARE
    leaf alias for $1;
    depth alias for $2;
    myrc feature_by_fx_type%ROWTYPE;
    myrc2 feature_by_fx_type%ROWTYPE;
BEGIN
    FOR myrc IN SELECT DISTINCT object_id AS feature_id, depth FROM feature_relationship WHERE subject_id = leaf LOOP
        RETURN NEXT myrc;
        FOR myrc2 IN SELECT * FROM get_up_feature_ids(myrc.feature_id,depth+1) LOOP
            RETURN NEXT myrc2;
        END LOOP;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION chado.get_up_feature_ids(integer, integer) OWNER TO www;

--
-- Name: gffattstring(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.gffattstring(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$DECLARE
  return_string      varchar;
  f_id               ALIAS FOR $1;
  atts_view          gffatts%ROWTYPE;
  feature_row        feature%ROWTYPE;
  name               varchar;
  uniquename         varchar;
  parent             varchar;
  escape_loc         int; 
BEGIN
  --Get name from feature.name
  --Get ID from feature.uniquename
  SELECT INTO feature_row * FROM feature WHERE feature_id = f_id;
  name  = feature_row.name;
  return_string = 'ID=' || feature_row.uniquename;
  IF name IS NOT NULL AND name != ''
  THEN
    return_string = return_string ||';' || 'Name=' || name;
  END IF;
  --Get Parent from feature_relationship
  SELECT INTO feature_row * FROM feature f, feature_relationship fr
    WHERE fr.subject_id = f_id AND fr.object_id = f.feature_id;
  IF FOUND
  THEN
    return_string = return_string||';'||'Parent='||feature_row.uniquename;
  END IF;
  FOR atts_view IN SELECT * FROM gff3atts WHERE feature_id = f_id  LOOP
    escape_loc = position(';' in atts_view.attribute);
    IF escape_loc > 0 THEN
      atts_view.attribute = replace(atts_view.attribute, ';', '%3B');
    END IF;
    return_string = return_string || ';'
                     || atts_view.type || '='
                     || atts_view.attribute;
  END LOOP;
  RETURN return_string;
END;
$_$;


ALTER FUNCTION chado.gffattstring(integer) OWNER TO www;

--
-- Name: db; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.db (
    db_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    urlprefix character varying(255),
    url character varying(255)
);


ALTER TABLE chado.db OWNER TO www;

--
-- Name: TABLE db; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.db IS 'A database authority. Typical databases in
bioinformatics are FlyBase, GO, UniProt, NCBI, MGI, etc. The authority
is generally known by this shortened form, which is unique within the
bioinformatics and biomedical realm.  To Do - add support for URIs,
URNs (e.g. LSIDs). We can do this by treating the URL as a URI -
however, some applications may expect this to be resolvable - to be
decided.';


--
-- Name: dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.dbxref (
    dbxref_id bigint NOT NULL,
    db_id bigint NOT NULL,
    accession character varying(1024) NOT NULL,
    version character varying(255) DEFAULT ''::character varying NOT NULL,
    description text
);


ALTER TABLE chado.dbxref OWNER TO www;

--
-- Name: TABLE dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.dbxref IS 'A unique, global, chado. stable identifier. Not necessarily an external reference - can reference data items inside the particular chado instance being used. Typically a row in a table can be uniquely identified with a primary identifier (called dbxref_id); a table may also have secondary identifiers (in a linking table <T>_dbxref). A dbxref is generally written as <DB>:<ACCESSION> or as <DB>:<ACCESSION>:<VERSION>.';


--
-- Name: COLUMN dbxref.accession; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.dbxref.accession IS 'The local part of the identifier. Guaranteed by the db authority to be unique for that db.';


--
-- Name: feature_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_cvterm (
    feature_cvterm_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_cvterm OWNER TO www;

--
-- Name: TABLE feature_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_cvterm IS 'Associate a term from a cv with a feature, for example, GO annotation.';


--
-- Name: COLUMN feature_cvterm.pub_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_cvterm.pub_id IS 'Provenance for the annotation. Each annotation should have a single primary chado.tion (which may be of the appropriate type for computational analyses) where more details can be found. Additional provenance dbxrefs can be attached using feature_cvterm_dbxref.';


--
-- Name: COLUMN feature_cvterm.is_not; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_cvterm.is_not IS 'If this is set to true, then this annotation is interpreted as a NEGATIVE annotation - i.e. the feature does NOT have the specified function, process, component, part, etc. See GO docs for more details.';


--
-- Name: feature_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_dbxref (
    feature_dbxref_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.feature_dbxref OWNER TO www;

--
-- Name: TABLE feature_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_dbxref IS 'Links a feature to dbxrefs.';


--
-- Name: COLUMN feature_dbxref.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_dbxref.is_current IS 'True if this secondary dbxref is 
the most up to date accession in the corresponding db. Retired accessions 
should set this field to false';


--
-- Name: feature_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_pub (
    feature_pub_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.feature_pub OWNER TO www;

--
-- Name: TABLE feature_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_pub IS 'Provenance. Linking table between features and chado.tions that mention them.';


--
-- Name: feature_synonym; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_synonym (
    feature_synonym_id bigint NOT NULL,
    synonym_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    is_internal boolean DEFAULT false NOT NULL
);


ALTER TABLE chado.feature_synonym OWNER TO www;

--
-- Name: TABLE feature_synonym; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_synonym IS 'Linking table between feature and synonym.';


--
-- Name: COLUMN feature_synonym.pub_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_synonym.pub_id IS 'The pub_id link is for relating the usage of a given synonym to the chado.tion in which it was used.';


--
-- Name: COLUMN feature_synonym.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_synonym.is_current IS 'The is_current boolean indicates whether the linked synonym is the  current -official- symbol for the linked feature.';


--
-- Name: COLUMN feature_synonym.is_internal; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_synonym.is_internal IS 'Typically a synonym exists so that somebody querying the db with an obsolete name can find the object theyre looking for (under its current name.  If the synonym has been used chado.y and deliberately (e.g. in a paper), it may also be listed in reports as a synonym. If the synonym was not used deliberately (e.g. there was a typo which went chado., then the is_internal boolean may be set to -true- so that it is known that the synonym is -internal- and should be queryable but should not be listed in reports as a valid synonym.';


--
-- Name: featureprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featureprop (
    featureprop_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.featureprop OWNER TO www;

--
-- Name: TABLE featureprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featureprop IS 'A feature can have any number of slot-value property tags attached to it. This is an alternative to hardcoding a list of columns in the relational schema, and is completely extensible.';


--
-- Name: COLUMN featureprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Certain property types will only apply to certain feature
types (e.g. the anticodon property will only apply to tRNA features) ;
the types here come from the sequence feature property ontology.';


--
-- Name: COLUMN featureprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation. This is less efficient than using native database types, but is easier to query.';


--
-- Name: COLUMN featureprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featureprop.rank IS 'Property-Value ordering. Any
feature can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used';


--
-- Name: pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pub (
    pub_id bigint NOT NULL,
    title text,
    volumetitle text,
    volume character varying(255),
    series_name character varying(255),
    issue character varying(255),
    pyear character varying(255),
    pages character varying(255),
    miniref character varying(255),
    uniquename text NOT NULL,
    type_id bigint NOT NULL,
    is_obsolete boolean DEFAULT false,
    publisher character varying(255),
    pubplace character varying(255)
);


ALTER TABLE chado.pub OWNER TO www;

--
-- Name: TABLE pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pub IS 'A documented provenance artefact - chado.tions,
documents, personal communication.';


--
-- Name: COLUMN pub.title; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pub.title IS 'Descriptive general heading.';


--
-- Name: COLUMN pub.volumetitle; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pub.volumetitle IS 'Title of part if one of a series.';


--
-- Name: COLUMN pub.series_name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pub.series_name IS 'Full name of (journal) series.';


--
-- Name: COLUMN pub.pages; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pub.pages IS 'Page number range[s], e.g. 457--459, viii + 664pp, lv--lvii.';


--
-- Name: COLUMN pub.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pub.type_id IS 'The type of the chado.tion (book, journal, poem, graffiti, etc). Uses pub cv.';


--
-- Name: synonym; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.synonym (
    synonym_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    type_id bigint NOT NULL,
    synonym_sgml character varying(255) NOT NULL
);


ALTER TABLE chado.synonym OWNER TO www;

--
-- Name: TABLE synonym; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.synonym IS 'A synonym for a feature. One feature can have multiple synonyms, and the same synonym can apply to multiple features.';


--
-- Name: COLUMN synonym.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.synonym.name IS 'The synonym itself. Should be human-readable machine-searchable ascii text.';


--
-- Name: COLUMN synonym.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.synonym.type_id IS 'Types would be symbol and fullname for now.';


--
-- Name: COLUMN synonym.synonym_sgml; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.synonym.synonym_sgml IS 'The fully specified synonym, with any non-ascii characters encoded in SGML.';


--
-- Name: gffatts; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.gffatts AS
 SELECT fs.feature_id,
    'Ontology_term'::text AS type,
    s.name AS attribute
   FROM chado.cvterm s,
    chado.feature_cvterm fs
  WHERE (fs.cvterm_id = s.cvterm_id)
UNION ALL
 SELECT fs.feature_id,
    'Dbxref'::text AS type,
    (((d.name)::text || ':'::text) || (s.accession)::text) AS attribute
   FROM chado.dbxref s,
    chado.feature_dbxref fs,
    chado.db d
  WHERE ((fs.dbxref_id = s.dbxref_id) AND (s.db_id = d.db_id))
UNION ALL
 SELECT fs.feature_id,
    'Alias'::text AS type,
    s.name AS attribute
   FROM chado.synonym s,
    chado.feature_synonym fs
  WHERE (fs.synonym_id = s.synonym_id)
UNION ALL
 SELECT fp.feature_id,
    cv.name AS type,
    fp.value AS attribute
   FROM chado.featureprop fp,
    chado.cvterm cv
  WHERE (fp.type_id = cv.cvterm_id)
UNION ALL
 SELECT fs.feature_id,
    'pub'::text AS type,
    (((s.series_name)::text || ':'::text) || s.title) AS attribute
   FROM chado.pub s,
    chado.feature_pub fs
  WHERE (fs.pub_id = s.pub_id);


ALTER TABLE chado.gffatts OWNER TO www;

--
-- Name: gfffeatureatts(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.gfffeatureatts(integer) RETURNS SETOF chado.gffatts
    LANGUAGE sql
    AS $_$
SELECT feature_id, 'Ontology_term' AS type,  s.name AS attribute
FROM cvterm s, feature_cvterm fs
WHERE fs.feature_id= $1 AND fs.cvterm_id = s.cvterm_id
UNION
SELECT feature_id, 'Dbxref' AS type, d.name || ':' || s.accession AS attribute
FROM dbxref s, feature_dbxref fs, db d
WHERE fs.feature_id= $1 AND fs.dbxref_id = s.dbxref_id AND s.db_id = d.db_id
UNION
SELECT feature_id, 'Alias' AS type, s.name AS attribute
FROM synonym s, feature_synonym fs
WHERE fs.feature_id= $1 AND fs.synonym_id = s.synonym_id
UNION
SELECT fp.feature_id,cv.name,fp.value
FROM featureprop fp, cvterm cv
WHERE fp.feature_id= $1 AND fp.type_id = cv.cvterm_id 
UNION
SELECT feature_id, 'pub' AS type, s.series_name || ':' || s.title AS attribute
FROM pub s, feature_pub fs
WHERE fs.feature_id= $1 AND fs.pub_id = s.pub_id
$_$;


ALTER FUNCTION chado.gfffeatureatts(integer) OWNER TO www;

--
-- Name: order_exons(integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.order_exons(integer) RETURNS void
    LANGUAGE plpgsql
    AS $_$
  DECLARE
    parent_type      ALIAS FOR $1;
    exon_id          int;
    part_of          int;
    exon_type        int;
    strand           int;
    arow             RECORD;
    order_by         varchar;
    rowcount         int;
    exon_count       int;
    ordered_exons    int;    
    transcript_id    int;
    transcript_row   feature%ROWTYPE;
  BEGIN
    SELECT INTO part_of cvterm_id FROM cvterm WHERE name='part_of'
      AND cv_id IN (SELECT cv_id FROM cv WHERE name='relationship');
    --SELECT INTO exon_type cvterm_id FROM cvterm WHERE name='exon'
    --  AND cv_id IN (SELECT cv_id FROM cv WHERE name='sequence');
    --RAISE NOTICE 'part_of %, exon %',part_of,exon_type;
    FOR transcript_row IN
      SELECT * FROM feature WHERE type_id = parent_type
    LOOP
      transcript_id = transcript_row.feature_id;
      SELECT INTO rowcount count(*) FROM feature_relationship
        WHERE object_id = transcript_id
          AND rank = 0;
      --Dont modify this transcript if there are already numbered exons or
      --if there is only one exon
      IF rowcount = 1 THEN
        --RAISE NOTICE 'skipping transcript %, row count %',transcript_id,rowcount;
        CONTINUE;
      END IF;
      --need to reverse the order if the strand is negative
      SELECT INTO strand strand FROM featureloc WHERE feature_id=transcript_id;
      IF strand > 0 THEN
          order_by = 'fl.fmin';      
      ELSE
          order_by = 'fl.fmax desc';
      END IF;
      exon_count = 0;
      FOR arow IN EXECUTE 
        'SELECT fr.*, fl.fmin, fl.fmax
          FROM feature_relationship fr, featureloc fl
          WHERE fr.object_id  = '||transcript_id||'
            AND fr.subject_id = fl.feature_id
            AND fr.type_id    = '||part_of||'
            ORDER BY '||order_by
      LOOP
        --number the exons for a given transcript
        UPDATE feature_relationship
          SET rank = exon_count 
          WHERE feature_relationship_id = arow.feature_relationship_id;
        exon_count = exon_count + 1;
      END LOOP; 
    END LOOP;
  END;
$_$;


ALTER FUNCTION chado.order_exons(integer) OWNER TO www;

--
-- Name: phylonode_depth(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.phylonode_depth(bigint) RETURNS double precision
    LANGUAGE plpgsql
    AS $_$DECLARE  id    ALIAS FOR $1;
  DECLARE  depth FLOAT := 0;
  DECLARE  curr_node phylonode%ROWTYPE;
  BEGIN
   SELECT INTO curr_node *
    FROM phylonode 
    WHERE phylonode_id=id;
   depth = depth + curr_node.distance;
   IF curr_node.parent_phylonode_id IS NULL
    THEN RETURN depth;
    ELSE RETURN depth + phylonode_depth(curr_node.parent_phylonode_id);
   END IF;
 END
$_$;


ALTER FUNCTION chado.phylonode_depth(bigint) OWNER TO www;

--
-- Name: phylonode_height(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.phylonode_height(bigint) RETURNS double precision
    LANGUAGE sql
    AS $_$
  SELECT coalesce(max(phylonode_height(phylonode_id) + distance), 0.0)
    FROM phylonode
    WHERE parent_phylonode_id = $1
$_$;


ALTER FUNCTION chado.phylonode_height(bigint) OWNER TO www;

--
-- Name: project_featureloc_up(integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.project_featureloc_up(integer, integer) RETURNS chado.featureloc
    LANGUAGE plpgsql
    AS $_$
DECLARE
    in_featureloc_id alias for $1;
    up_srcfeature_id alias for $2;
    in_featureloc featureloc%ROWTYPE;
    up_featureloc featureloc%ROWTYPE;
    nu_featureloc featureloc%ROWTYPE;
    nu_fmin INT;
    nu_fmax INT;
    nu_strand INT;
BEGIN
 SELECT INTO in_featureloc
   featureloc.*
  FROM featureloc
  WHERE featureloc_id = in_featureloc_id;
 SELECT INTO up_featureloc
   up_fl.*
  FROM featureloc AS in_fl
  INNER JOIN featureloc AS up_fl
    ON (in_fl.srcfeature_id = up_fl.feature_id)
  WHERE
   in_fl.featureloc_id = in_featureloc_id AND
   up_fl.srcfeature_id = up_srcfeature_id;
  IF up_featureloc.strand IS NULL
   THEN RETURN NULL;
  END IF;
  IF up_featureloc.strand < 0
  THEN
   nu_fmin = project_point_up(in_featureloc.fmax,
                              up_featureloc.fmin,up_featureloc.fmax,-1);
   nu_fmax = project_point_up(in_featureloc.fmin,
                              up_featureloc.fmin,up_featureloc.fmax,-1);
   nu_strand = -in_featureloc.strand;
  ELSE
   nu_fmin = project_point_up(in_featureloc.fmin,
                              up_featureloc.fmin,up_featureloc.fmax,1);
   nu_fmax = project_point_up(in_featureloc.fmax,
                              up_featureloc.fmin,up_featureloc.fmax,1);
   nu_strand = in_featureloc.strand;
  END IF;
  in_featureloc.fmin = nu_fmin;
  in_featureloc.fmax = nu_fmax;
  in_featureloc.strand = nu_strand;
  in_featureloc.srcfeature_id = up_featureloc.srcfeature_id;
  RETURN in_featureloc;
END
$_$;


ALTER FUNCTION chado.project_featureloc_up(integer, integer) OWNER TO www;

--
-- Name: project_point_down(integer, integer, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.project_point_down(integer, integer, integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$SELECT
  CASE WHEN $4<0
   THEN $3-$1
   ELSE $1+$2
  END AS p$_$;


ALTER FUNCTION chado.project_point_down(integer, integer, integer, integer) OWNER TO www;

--
-- Name: project_point_g2t(integer, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.project_point_g2t(integer, integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
 DECLARE
    in_p             alias for $1;
    srcf_id          alias for $2;
    t_id             alias for $3;
    e_floc           featureloc%ROWTYPE;
    out_p            INT;
    exon_cvterm_id   INT;
BEGIN
 SELECT INTO exon_cvterm_id get_feature_type_id('exon');
 SELECT INTO out_p
  CASE 
   WHEN strand<0 THEN fmax-p
   ELSE p-fmin
   END AS p
  FROM featureloc
   INNER JOIN feature USING (feature_id)
   INNER JOIN feature_relationship ON (feature.feature_id=subject_id)
  WHERE
   object_id = t_id                     AND
   feature.type_id = exon_cvterm_id     AND
   featureloc.srcfeature_id = srcf_id   AND
   in_p >= fmin                         AND
   in_p <= fmax;
  RETURN in_featureloc;
END
$_$;


ALTER FUNCTION chado.project_point_g2t(integer, integer, integer) OWNER TO www;

--
-- Name: project_point_up(integer, integer, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.project_point_up(integer, integer, integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$SELECT
  CASE WHEN $4<0
   THEN $3-$1             -- rev strand
   ELSE $1-$2             -- fwd strand
  END AS p$_$;


ALTER FUNCTION chado.project_point_up(integer, integer, integer, integer) OWNER TO www;

--
-- Name: reverse_complement(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.reverse_complement(text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT reverse_string(complement_residues($1))$_$;


ALTER FUNCTION chado.reverse_complement(text) OWNER TO www;

--
-- Name: reverse_string(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.reverse_string(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
 DECLARE 
  reversed_string TEXT;
  incoming ALIAS FOR $1;
 BEGIN
   reversed_string = '';
   FOR i IN REVERSE char_length(incoming)..1 loop
     reversed_string = reversed_string || substring(incoming FROM i FOR 1);
   END loop;
 RETURN reversed_string;
END$_$;


ALTER FUNCTION chado.reverse_string(text) OWNER TO www;

--
-- Name: search_columns(text, name[], name[]); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.search_columns(needle text, haystack_tables name[] DEFAULT '{}'::name[], haystack_schema name[] DEFAULT '{public}'::name[]) RETURNS TABLE(schemaname text, tablename text, columnname text, rowctid text)
    LANGUAGE plpgsql
    AS $$
begin
  FOR schemaname,tablename,columnname IN
      SELECT c.table_schema,c.table_name,c.column_name
      FROM information_schema.columns c
      JOIN information_schema.tables t ON
        (t.table_name=c.table_name AND t.table_schema=c.table_schema)
      WHERE (c.table_name=ANY(haystack_tables) OR haystack_tables='{}')
        AND c.table_schema=ANY(haystack_schema)
        AND t.table_type='BASE TABLE'
  LOOP
    EXECUTE format('SELECT ctid FROM %I.%I WHERE cast(%I as text)=%L',
       schemaname,
       tablename,
       columnname,
       needle
    ) INTO rowctid;
    IF rowctid is not null THEN
      RETURN NEXT;
    END IF;
 END LOOP;
END;
$$;


ALTER FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) OWNER TO www;

--
-- Name: set_secondary_marker_pub(integer, text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.set_secondary_marker_pub(integer, text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    pubid    alias for $1;
    matchstr alias for $2;
    markerid int;
    
BEGIN
    FOR markerid IN SELECT feature_id FROM feature WHERE name LIKE matchstr LOOP
      RAISE NOTICE 'set % as secondary publication for %', pubid, markerid;
      INSERT INTO feature_pub 
        (feature_id, pub_id)
      VALUES
        (markerid, pubid);
    END LOOP;
    RETURN 0;
END;
$_$;


ALTER FUNCTION chado.set_secondary_marker_pub(integer, text) OWNER TO www;

--
-- Name: share_exons(); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.share_exons() RETURNS void
    LANGUAGE plpgsql
    AS $$    
  DECLARE    
  BEGIN
    CREATE temporary TABLE shared_exons AS
      SELECT gene.feature_id as gene_feature_id
           , gene.uniquename as gene_uniquename
           , transcript1.uniquename as transcript1
           , exon1.feature_id as exon1_feature_id
           , exon1.uniquename as exon1_uniquename
           , transcript2.uniquename as transcript2
           , exon2.feature_id as exon2_feature_id
           , exon2.uniquename as exon2_uniquename
           , exon1_loc.fmin 
           , exon1_loc.fmax 
      FROM feature gene
        JOIN cvterm gene_type ON gene.type_id = gene_type.cvterm_id
        JOIN cv gene_type_cv USING (cv_id)
        JOIN feature_relationship gene_transcript1 ON gene.feature_id = gene_transcript1.object_id
        JOIN feature transcript1 ON gene_transcript1.subject_id = transcript1.feature_id
        JOIN cvterm transcript1_type ON transcript1.type_id = transcript1_type.cvterm_id
        JOIN cv transcript1_type_cv ON transcript1_type.cv_id = transcript1_type_cv.cv_id
        JOIN feature_relationship transcript1_exon1 ON transcript1_exon1.object_id = transcript1.feature_id
        JOIN feature exon1 ON transcript1_exon1.subject_id = exon1.feature_id
        JOIN cvterm exon1_type ON exon1.type_id = exon1_type.cvterm_id
        JOIN cv exon1_type_cv ON exon1_type.cv_id = exon1_type_cv.cv_id
        JOIN featureloc exon1_loc ON exon1_loc.feature_id = exon1.feature_id
        JOIN feature_relationship gene_transcript2 ON gene.feature_id = gene_transcript2.object_id
        JOIN feature transcript2 ON gene_transcript2.subject_id = transcript2.feature_id
        JOIN cvterm transcript2_type ON transcript2.type_id = transcript2_type.cvterm_id
        JOIN cv transcript2_type_cv ON transcript2_type.cv_id = transcript2_type_cv.cv_id
        JOIN feature_relationship transcript2_exon2 ON transcript2_exon2.object_id = transcript2.feature_id
        JOIN feature exon2 ON transcript2_exon2.subject_id = exon2.feature_id
        JOIN cvterm exon2_type ON exon2.type_id = exon2_type.cvterm_id
        JOIN cv exon2_type_cv ON exon2_type.cv_id = exon2_type_cv.cv_id
        JOIN featureloc exon2_loc ON exon2_loc.feature_id = exon2.feature_id
      WHERE gene_type_cv.name = 'sequence'
        AND gene_type.name = 'gene'
        AND transcript1_type_cv.name = 'sequence'
        AND transcript1_type.name = 'mRNA'
        AND transcript2_type_cv.name = 'sequence'
        AND transcript2_type.name = 'mRNA'
        AND exon1_type_cv.name = 'sequence'
        AND exon1_type.name = 'exon'
        AND exon2_type_cv.name = 'sequence'
        AND exon2_type.name = 'exon'
        AND exon1.feature_id < exon2.feature_id
        AND exon1_loc.rank = 0
        AND exon2_loc.rank = 0
        AND exon1_loc.fmin = exon2_loc.fmin
        AND exon1_loc.fmax = exon2_loc.fmax
    ;
    /* Choose one of the shared exons to be the canonical representative.
       We pick the one with the smallest feature_id.
     */
    CREATE temporary TABLE canonical_exon_representatives AS
      SELECT gene_feature_id, min(exon1_feature_id) AS canonical_feature_id, fmin
      FROM shared_exons
      GROUP BY gene_feature_id,fmin
    ;
    CREATE temporary TABLE exon_replacements AS
      SELECT DISTINCT shared_exons.exon2_feature_id AS actual_feature_id
                    , canonical_exon_representatives.canonical_feature_id
                    , canonical_exon_representatives.fmin
      FROM shared_exons
        JOIN canonical_exon_representatives USING (gene_feature_id)
      WHERE shared_exons.exon2_feature_id <> canonical_exon_representatives.canonical_feature_id
        AND shared_exons.fmin = canonical_exon_representatives.fmin
    ;
    UPDATE feature_relationship 
      SET subject_id = (
            SELECT canonical_feature_id
            FROM exon_replacements
            WHERE feature_relationship.subject_id = exon_replacements.actual_feature_id)
      WHERE subject_id IN (
        SELECT actual_feature_id FROM exon_replacements
    );
    UPDATE feature_relationship
      SET object_id = (
            SELECT canonical_feature_id
            FROM exon_replacements
            WHERE feature_relationship.subject_id = exon_replacements.actual_feature_id)
      WHERE object_id IN (
        SELECT actual_feature_id FROM exon_replacements
    );
    UPDATE feature
      SET is_obsolete = true
      WHERE feature_id IN (
        SELECT actual_feature_id FROM exon_replacements
    );
  END;    
$$;


ALTER FUNCTION chado.share_exons() OWNER TO www;

--
-- Name: store_analysis(character varying, character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_analysis(character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
   v_program            ALIAS FOR $1;
   v_programversion     ALIAS FOR $2;
   v_sourcename         ALIAS FOR $3;
   pkval                INTEGER;
 BEGIN
    SELECT INTO pkval analysis_id
      FROM analysis
      WHERE program=v_program AND
            programversion=v_programversion AND
            sourcename=v_sourcename;
    IF NOT FOUND THEN
      INSERT INTO analysis 
       (program,programversion,sourcename)
         VALUES
       (v_program,v_programversion,v_sourcename);
      RETURN currval('analysis_analysis_id_seq');
    END IF;
    RETURN pkval;
 END;
$_$;


ALTER FUNCTION chado.store_analysis(character varying, character varying, character varying) OWNER TO www;

--
-- Name: store_db(character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_db(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
   v_name             ALIAS FOR $1;
   v_db_id            INTEGER;
 BEGIN
    SELECT INTO v_db_id db_id
      FROM db
      WHERE name=v_name;
    IF NOT FOUND THEN
      INSERT INTO db
       (name)
         VALUES
       (v_name);
       RETURN currval('db_db_id_seq');
    END IF;
    RETURN v_db_id;
 END;
$_$;


ALTER FUNCTION chado.store_db(character varying) OWNER TO www;

--
-- Name: store_dbxref(character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_dbxref(character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
   v_dbname                ALIAS FOR $1;
   v_accession             ALIAS FOR $1;
   v_db_id                 INTEGER;
   v_dbxref_id             INTEGER;
 BEGIN
    SELECT INTO v_db_id
      store_db(v_dbname);
    SELECT INTO v_dbxref_id dbxref_id
      FROM dbxref
      WHERE db_id=v_db_id       AND
            accession=v_accession;
    IF NOT FOUND THEN
      INSERT INTO dbxref
       (db_id,accession)
         VALUES
       (v_db_id,v_accession);
       RETURN currval('dbxref_dbxref_id_seq');
    END IF;
    RETURN v_dbxref_id;
 END;
$_$;


ALTER FUNCTION chado.store_dbxref(character varying, character varying) OWNER TO www;

--
-- Name: store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
  v_srcfeature_id       ALIAS FOR $1;
  v_fmin                ALIAS FOR $2;
  v_fmax                ALIAS FOR $3;
  v_strand              ALIAS FOR $4;
  v_dbxref_id           ALIAS FOR $5;
  v_organism_id         ALIAS FOR $6;
  v_name                ALIAS FOR $7;
  v_uniquename          ALIAS FOR $8;
  v_type_id             ALIAS FOR $9;
  v_is_analysis         ALIAS FOR $10;
  v_feature_id          INT;
  v_featureloc_id       INT;
 BEGIN
    IF v_dbxref_id IS NULL THEN
      SELECT INTO v_feature_id feature_id
      FROM feature
      WHERE uniquename=v_uniquename     AND
            organism_id=v_organism_id   AND
            type_id=v_type_id;
    ELSE
      SELECT INTO v_feature_id feature_id
      FROM feature
      WHERE dbxref_id=v_dbxref_id;
    END IF;
    IF NOT FOUND THEN
      INSERT INTO feature
       ( dbxref_id           ,
         organism_id         ,
         name                ,
         uniquename          ,
         type_id             ,
         is_analysis         )
        VALUES
        ( v_dbxref_id           ,
          v_organism_id         ,
          v_name                ,
          v_uniquename          ,
          v_type_id             ,
          v_is_analysis         );
      v_feature_id = currval('feature_feature_id_seq');
    ELSE
      UPDATE feature SET
        dbxref_id   =  v_dbxref_id           ,
        organism_id =  v_organism_id         ,
        name        =  v_name                ,
        uniquename  =  v_uniquename          ,
        type_id     =  v_type_id             ,
        is_analysis =  v_is_analysis
      WHERE
        feature_id=v_feature_id;
    END IF;
  PERFORM store_featureloc(v_feature_id,
                           v_srcfeature_id,
                           v_fmin,
                           v_fmax,
                           v_strand,
                           0,
                           0);
  RETURN v_feature_id;
 END;
$_$;


ALTER FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) OWNER TO www;

--
-- Name: store_feature_synonym(integer, character varying, integer, boolean, boolean, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
  v_feature_id          ALIAS FOR $1;
  v_syn                 ALIAS FOR $2;
  v_type_id             ALIAS FOR $3;
  v_is_current          ALIAS FOR $4;
  v_is_internal         ALIAS FOR $5;
  v_pub_id              ALIAS FOR $6;
  v_synonym_id          INT;
  v_feature_synonym_id  INT;
 BEGIN
    IF v_feature_id IS NULL THEN RAISE EXCEPTION 'feature_id cannot be null';
    END IF;
    SELECT INTO v_synonym_id synonym_id
      FROM synonym
      WHERE name=v_syn                  AND
            type_id=v_type_id;
    IF NOT FOUND THEN
      INSERT INTO synonym
        ( name,
          synonym_sgml,
          type_id)
        VALUES
        ( v_syn,
          v_syn,
          v_type_id);
      v_synonym_id = currval('synonym_synonym_id_seq');
    END IF;
    SELECT INTO v_feature_synonym_id feature_synonym_id
        FROM feature_synonym
        WHERE feature_id=v_feature_id   AND
              synonym_id=v_synonym_id   AND
              pub_id=v_pub_id;
    IF NOT FOUND THEN
      INSERT INTO feature_synonym
        ( feature_id,
          synonym_id,
          pub_id,
          is_current,
          is_internal)
        VALUES
        ( v_feature_id,
          v_synonym_id,
          v_pub_id,
          v_is_current,
          v_is_internal);
      v_feature_synonym_id = currval('feature_synonym_feature_synonym_id_seq');
    ELSE
      UPDATE feature_synonym
        SET is_current=v_is_current, is_internal=v_is_internal
        WHERE feature_synonym_id=v_feature_synonym_id;
    END IF;
  RETURN v_feature_synonym_id;
 END;
$_$;


ALTER FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) OWNER TO www;

--
-- Name: store_featureloc(integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
  v_feature_id          ALIAS FOR $1;
  v_srcfeature_id       ALIAS FOR $2;
  v_fmin                ALIAS FOR $3;
  v_fmax                ALIAS FOR $4;
  v_strand              ALIAS FOR $5;
  v_rank                ALIAS FOR $6;
  v_locgroup            ALIAS FOR $7;
  v_featureloc_id       INT;
 BEGIN
    IF v_feature_id IS NULL THEN RAISE EXCEPTION 'feature_id cannot be null';
    END IF;
    SELECT INTO v_featureloc_id featureloc_id
      FROM featureloc
      WHERE feature_id=v_feature_id     AND
            rank=v_rank                 AND
            locgroup=v_locgroup;
    IF NOT FOUND THEN
      INSERT INTO featureloc
        ( feature_id,
          srcfeature_id,
          fmin,
          fmax,
          strand,
          rank,
          locgroup)
        VALUES
        (  v_feature_id,
           v_srcfeature_id,
           v_fmin,
           v_fmax,
           v_strand,
           v_rank,
           v_locgroup);
      v_featureloc_id = currval('featureloc_featureloc_id_seq');
    ELSE
      UPDATE featureloc SET
        feature_id    =  v_feature_id,
        srcfeature_id =  v_srcfeature_id,
        fmin          =  v_fmin,
        fmax          =  v_fmax,
        strand        =  v_strand,
        rank          =  v_rank,
        locgroup      =  v_locgroup
      WHERE
        featureloc_id=v_featureloc_id;
    END IF;
  RETURN v_featureloc_id;
 END;
$_$;


ALTER FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) OWNER TO www;

--
-- Name: store_organism(character varying, character varying, character varying); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.store_organism(character varying, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$DECLARE
   v_genus            ALIAS FOR $1;
   v_species          ALIAS FOR $2;
   v_common_name      ALIAS FOR $3;
   v_organism_id      INTEGER;
 BEGIN
    SELECT INTO v_organism_id organism_id
      FROM organism
      WHERE genus=v_genus               AND
            species=v_species;
    IF NOT FOUND THEN
      INSERT INTO organism
       (genus,species,common_name)
         VALUES
       (v_genus,v_species,v_common_name);
       RETURN currval('organism_organism_id_seq');
    ELSE
      UPDATE organism
       SET common_name=v_common_name
      WHERE organism_id = v_organism_id;
    END IF;
    RETURN v_organism_id;
 END;
$_$;


ALTER FUNCTION chado.store_organism(character varying, character varying, character varying) OWNER TO www;

--
-- Name: subsequence(bigint, bigint, bigint, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence(bigint, bigint, bigint, integer) RETURNS text
    LANGUAGE sql
    AS $_$SELECT 
  CASE WHEN $4<0 
   THEN reverse_complement(substring(srcf.residues,CAST(($2+1) as int),CAST(($3-$2) as int)))
   ELSE substring(residues,CAST(($2+1) as int),CAST(($3-$2) as int))
  END AS residues
  FROM feature AS srcf
  WHERE
   srcf.feature_id=$1$_$;


ALTER FUNCTION chado.subsequence(bigint, bigint, bigint, integer) OWNER TO www;

--
-- Name: subsequence_by_feature(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_feature(bigint) RETURNS text
    LANGUAGE sql
    AS $_$SELECT subsequence_by_feature($1,0,0)$_$;


ALTER FUNCTION chado.subsequence_by_feature(bigint) OWNER TO www;

--
-- Name: subsequence_by_feature(bigint, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_feature(bigint, integer, integer) RETURNS text
    LANGUAGE sql
    AS $_$SELECT 
  CASE WHEN strand<0 
   THEN reverse_complement(substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int)))
   ELSE substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int))
  END AS residues
  FROM feature AS srcf
   INNER JOIN featureloc ON (srcf.feature_id=featureloc.srcfeature_id)
  WHERE
   featureloc.feature_id=$1 AND
   featureloc.rank=$2 AND
   featureloc.locgroup=$3$_$;


ALTER FUNCTION chado.subsequence_by_feature(bigint, integer, integer) OWNER TO www;

--
-- Name: subsequence_by_featureloc(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_featureloc(bigint) RETURNS text
    LANGUAGE sql
    AS $_$SELECT 
  CASE WHEN strand<0 
   THEN reverse_complement(substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int)))
   ELSE substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int))
  END AS residues
  FROM feature AS srcf
   INNER JOIN featureloc ON (srcf.feature_id=featureloc.srcfeature_id)
  WHERE
   featureloc_id=$1$_$;


ALTER FUNCTION chado.subsequence_by_featureloc(bigint) OWNER TO www;

--
-- Name: subsequence_by_subfeatures(bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_subfeatures(bigint) RETURNS text
    LANGUAGE sql
    AS $_$
SELECT subsequence_by_subfeatures($1,get_feature_relationship_type_id('part_of'),0,0)
$_$;


ALTER FUNCTION chado.subsequence_by_subfeatures(bigint) OWNER TO www;

--
-- Name: subsequence_by_subfeatures(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) RETURNS text
    LANGUAGE sql
    AS $_$SELECT subsequence_by_subfeatures($1,$2,0,0)$_$;


ALTER FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) OWNER TO www;

--
-- Name: subsequence_by_subfeatures(bigint, bigint, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE v_feature_id ALIAS FOR $1;
DECLARE v_rtype_id   ALIAS FOR $2;
DECLARE v_rank       ALIAS FOR $3;
DECLARE v_locgroup   ALIAS FOR $4;
DECLARE subseq       TEXT;
DECLARE seqrow       RECORD;
BEGIN 
  subseq = '';
 FOR seqrow IN
   SELECT
    CASE WHEN strand<0 
     THEN reverse_complement(substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int)))
     ELSE substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int))
    END AS residues
    FROM feature AS srcf
     INNER JOIN featureloc ON (srcf.feature_id=featureloc.srcfeature_id)
     INNER JOIN feature_relationship AS fr
       ON (fr.subject_id=featureloc.feature_id)
    WHERE
     fr.object_id=v_feature_id AND
     fr.type_id=v_rtype_id AND
     featureloc.rank=v_rank AND
     featureloc.locgroup=v_locgroup
    ORDER BY fr.rank
  LOOP
   subseq = subseq  || seqrow.residues;
  END LOOP;
 RETURN subseq;
END
$_$;


ALTER FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) OWNER TO www;

--
-- Name: subsequence_by_typed_subfeatures(bigint, bigint); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) RETURNS text
    LANGUAGE sql
    AS $_$SELECT subsequence_by_typed_subfeatures($1,$2,0,0)$_$;


ALTER FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) OWNER TO www;

--
-- Name: subsequence_by_typed_subfeatures(bigint, bigint, integer, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
DECLARE v_feature_id ALIAS FOR $1;
DECLARE v_ftype_id   ALIAS FOR $2;
DECLARE v_rank       ALIAS FOR $3;
DECLARE v_locgroup   ALIAS FOR $4;
DECLARE subseq       TEXT;
DECLARE seqrow       RECORD;
BEGIN 
  subseq = '';
 FOR seqrow IN
   SELECT
    CASE WHEN strand<0 
     THEN reverse_complement(substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int)))
     ELSE substring(srcf.residues,CAST(fmin+1 as int),CAST((fmax-fmin) as int))
    END AS residues
  FROM feature AS srcf
   INNER JOIN featureloc ON (srcf.feature_id=featureloc.srcfeature_id)
   INNER JOIN feature AS subf ON (subf.feature_id=featureloc.feature_id)
   INNER JOIN feature_relationship AS fr ON (fr.subject_id=subf.feature_id)
  WHERE
     fr.object_id=v_feature_id AND
     subf.type_id=v_ftype_id AND
     featureloc.rank=v_rank AND
     featureloc.locgroup=v_locgroup
  ORDER BY fr.rank
   LOOP
   subseq = subseq  || seqrow.residues;
  END LOOP;
 RETURN subseq;
END
$_$;


ALTER FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) OWNER TO www;

--
-- Name: translate_codon(text, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.translate_codon(text, integer) RETURNS character
    LANGUAGE sql
    AS $_$SELECT aa FROM genetic_code.gencode_codon_aa WHERE codon=$1 AND gencode_id=$2$_$;


ALTER FUNCTION chado.translate_codon(text, integer) OWNER TO www;

--
-- Name: translate_dna(text); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.translate_dna(text) RETURNS text
    LANGUAGE sql
    AS $_$SELECT translate_dna($1,1)$_$;


ALTER FUNCTION chado.translate_dna(text) OWNER TO www;

--
-- Name: translate_dna(text, integer); Type: FUNCTION; Schema: chado; Owner: www
--

CREATE FUNCTION chado.translate_dna(text, integer) RETURNS text
    LANGUAGE plpgsql
    AS $_$
 DECLARE 
  dnaseq ALIAS FOR $1;
  gcode ALIAS FOR $2;
  translation TEXT;
  dnaseqlen INT;
  codon CHAR(3);
  aa CHAR(1);
  i INT;
 BEGIN
   translation = '';
   dnaseqlen = char_length(dnaseq);
   i=1;
   WHILE i+1 < dnaseqlen loop
     codon = substring(dnaseq,i,3);
     aa = translate_codon(codon,gcode);
     translation = translation || aa;
     i = i+3;
   END loop;
 RETURN translation;
END$_$;


ALTER FUNCTION chado.translate_dna(text, integer) OWNER TO www;

--
-- Name: concat(text); Type: AGGREGATE; Schema: chado; Owner: www
--

CREATE AGGREGATE chado.concat(text) (
    SFUNC = chado.concat_pair,
    STYPE = text,
    INITCOND = ''
);


ALTER AGGREGATE chado.concat(text) OWNER TO www;

--
-- Name: acquisition; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.acquisition (
    acquisition_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    protocol_id bigint,
    channel_id bigint,
    acquisitiondate timestamp without time zone DEFAULT now(),
    name text,
    uri text
);


ALTER TABLE chado.acquisition OWNER TO www;

--
-- Name: TABLE acquisition; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.acquisition IS 'This represents the scanning of hybridized material. The output of this process is typically a digital image of an array.';


--
-- Name: acquisition_acquisition_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.acquisition_acquisition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.acquisition_acquisition_id_seq OWNER TO www;

--
-- Name: acquisition_acquisition_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.acquisition_acquisition_id_seq OWNED BY chado.acquisition.acquisition_id;


--
-- Name: acquisition_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.acquisition_relationship (
    acquisition_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    type_id bigint NOT NULL,
    object_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.acquisition_relationship OWNER TO www;

--
-- Name: TABLE acquisition_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.acquisition_relationship IS 'Multiple monochrome images may be merged to form a multi-color image. Red-green images of 2-channel hybridizations are an example of this.';


--
-- Name: acquisition_relationship_acquisition_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.acquisition_relationship_acquisition_relationship_id_seq OWNER TO www;

--
-- Name: acquisition_relationship_acquisition_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq OWNED BY chado.acquisition_relationship.acquisition_relationship_id;


--
-- Name: acquisitionprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.acquisitionprop (
    acquisitionprop_id bigint NOT NULL,
    acquisition_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.acquisitionprop OWNER TO www;

--
-- Name: TABLE acquisitionprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.acquisitionprop IS 'Parameters associated with image acquisition.';


--
-- Name: acquisitionprop_acquisitionprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.acquisitionprop_acquisitionprop_id_seq OWNER TO www;

--
-- Name: acquisitionprop_acquisitionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq OWNED BY chado.acquisitionprop.acquisitionprop_id;


--
-- Name: all_feature_names; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.all_feature_names AS
 SELECT feature.feature_id,
    ("substring"(feature.uniquename, 0, 255))::character varying(255) AS name,
    feature.organism_id
   FROM chado.feature
UNION
 SELECT feature.feature_id,
    feature.name,
    feature.organism_id
   FROM chado.feature
  WHERE (feature.name IS NOT NULL)
UNION
 SELECT fs.feature_id,
    s.name,
    f.organism_id
   FROM chado.feature_synonym fs,
    chado.synonym s,
    chado.feature f
  WHERE ((fs.synonym_id = s.synonym_id) AND (fs.feature_id = f.feature_id))
UNION
 SELECT fp.feature_id,
    ("substring"(fp.value, 0, 255))::character varying(255) AS name,
    f.organism_id
   FROM chado.featureprop fp,
    chado.feature f
  WHERE (f.feature_id = fp.feature_id)
UNION
 SELECT fd.feature_id,
    d.accession AS name,
    f.organism_id
   FROM chado.feature_dbxref fd,
    chado.dbxref d,
    chado.feature f
  WHERE ((fd.dbxref_id = d.dbxref_id) AND (fd.feature_id = f.feature_id));


ALTER TABLE chado.all_feature_names OWNER TO www;

--
-- Name: analysis; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis (
    analysis_id bigint NOT NULL,
    name character varying(255),
    description text,
    program character varying(255) NOT NULL,
    programversion character varying(255) NOT NULL,
    algorithm character varying(255),
    sourcename character varying(255),
    sourceversion character varying(255),
    sourceuri text,
    timeexecuted timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE chado.analysis OWNER TO www;

--
-- Name: TABLE analysis; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.analysis IS 'An analysis is a particular type of a
    computational analysis; it may be a blast of one sequence against
    another, or an all by all blast, or a different kind of analysis
    altogether. It is a single unit of computation.';


--
-- Name: COLUMN analysis.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.name IS 'A way of grouping analyses. This
    should be a handy short identifier that can help people find an
    analysis they want. For instance "tRNAscan", "cDNA", "FlyPep",
    "SwissProt", and it should not be assumed to be unique. For instance, there may be lots of separate analyses done against a cDNA database.';


--
-- Name: COLUMN analysis.program; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.program IS 'Program name, e.g. blastx, blastp, sim4, genscan.';


--
-- Name: COLUMN analysis.programversion; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.programversion IS 'Version description, e.g. TBLASTX 2.0MP-WashU [09-Nov-2000].';


--
-- Name: COLUMN analysis.algorithm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.algorithm IS 'Algorithm name, e.g. blast.';


--
-- Name: COLUMN analysis.sourcename; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.sourcename IS 'Source name, e.g. cDNA, SwissProt.';


--
-- Name: COLUMN analysis.sourceuri; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis.sourceuri IS 'This is an optional, permanent URL or URI for the source of the  analysis. The idea is that someone could recreate the analysis directly by going to this URI and fetching the source data (e.g. the blast database, or the training model).';


--
-- Name: analysis_analysis_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysis_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysis_analysis_id_seq OWNER TO www;

--
-- Name: analysis_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysis_analysis_id_seq OWNED BY chado.analysis.analysis_id;


--
-- Name: analysis_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis_cvterm (
    analysis_cvterm_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.analysis_cvterm OWNER TO www;

--
-- Name: TABLE analysis_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.analysis_cvterm IS 'Associate a term from a cv with an analysis.';


--
-- Name: COLUMN analysis_cvterm.is_not; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_cvterm.is_not IS 'If this is set to true, then this 
annotation is interpreted as a NEGATIVE annotation - i.e. the analysis does 
NOT have the specified term.';


--
-- Name: analysis_cvterm_analysis_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysis_cvterm_analysis_cvterm_id_seq OWNER TO www;

--
-- Name: analysis_cvterm_analysis_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq OWNED BY chado.analysis_cvterm.analysis_cvterm_id;


--
-- Name: analysis_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis_dbxref (
    analysis_dbxref_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.analysis_dbxref OWNER TO www;

--
-- Name: TABLE analysis_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.analysis_dbxref IS 'Links an analysis to dbxrefs.';


--
-- Name: COLUMN analysis_dbxref.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_dbxref.is_current IS 'True if this dbxref 
is the most up to date accession in the corresponding db. Retired 
accessions should set this field to false';


--
-- Name: analysis_dbxref_analysis_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysis_dbxref_analysis_dbxref_id_seq OWNER TO www;

--
-- Name: analysis_dbxref_analysis_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq OWNED BY chado.analysis_dbxref.analysis_dbxref_id;


--
-- Name: analysis_organism; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis_organism (
    analysis_id integer NOT NULL,
    organism_id integer NOT NULL
);


ALTER TABLE chado.analysis_organism OWNER TO www;

--
-- Name: analysis_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis_pub (
    analysis_pub_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.analysis_pub OWNER TO www;

--
-- Name: TABLE analysis_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.analysis_pub IS 'Provenance. Linking table between analyses and the publications that mention them.';


--
-- Name: analysis_pub_analysis_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysis_pub_analysis_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysis_pub_analysis_pub_id_seq OWNER TO www;

--
-- Name: analysis_pub_analysis_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysis_pub_analysis_pub_id_seq OWNED BY chado.analysis_pub.analysis_pub_id;


--
-- Name: analysis_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysis_relationship (
    analysis_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.analysis_relationship OWNER TO www;

--
-- Name: COLUMN analysis_relationship.subject_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_relationship.subject_id IS 'analysis_relationship.subject_id i
s the subject of the subj-predicate-obj sentence.';


--
-- Name: COLUMN analysis_relationship.object_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_relationship.object_id IS 'analysis_relationship.object_id 
is the object of the subj-predicate-obj sentence.';


--
-- Name: COLUMN analysis_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_relationship.type_id IS 'analysis_relationship.type_id 
is relationship type between subject and object. This is a cvterm, typically 
from the OBO relationship ontology, although other relationship types are allowed.';


--
-- Name: COLUMN analysis_relationship.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_relationship.value IS 'analysis_relationship.value 
is for additional notes or comments.';


--
-- Name: COLUMN analysis_relationship.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysis_relationship.rank IS 'analysis_relationship.rank is 
the ordering of subject analysiss with respect to the object analysis may be 
important where rank is used to order these; starts from zero.';


--
-- Name: analysis_relationship_analysis_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysis_relationship_analysis_relationship_id_seq OWNER TO www;

--
-- Name: analysis_relationship_analysis_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq OWNED BY chado.analysis_relationship.analysis_relationship_id;


--
-- Name: analysisfeature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysisfeature (
    analysisfeature_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    rawscore double precision,
    normscore double precision,
    significance double precision,
    identity double precision
);


ALTER TABLE chado.analysisfeature OWNER TO www;

--
-- Name: TABLE analysisfeature; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.analysisfeature IS 'Computational analyses generate features (e.g. Genscan generates transcripts and exons; sim4 alignments generate similarity/match features). analysisfeatures are stored using the feature table from the sequence module. The analysisfeature table is used to decorate these features, with analysis specific attributes. A feature is an analysisfeature if and only if there is a corresponding entry in the analysisfeature table. analysisfeatures will have two or more featureloc entries,
 with rank indicating query/subject';


--
-- Name: COLUMN analysisfeature.rawscore; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysisfeature.rawscore IS 'This is the native score generated by the program; for example, the bitscore generated by blast, sim4 or genscan scores. One should not assume that high is necessarily better than low.';


--
-- Name: COLUMN analysisfeature.normscore; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysisfeature.normscore IS 'This is the rawscore but
    semi-normalized. Complete normalization to allow comparison of
    features generated by different programs would be nice but too
    difficult. Instead the normalization should strive to enforce the
    following semantics: * normscores are floating point numbers >= 0,
    * high normscores are better than low one. For most programs, it would be sufficient to make the normscore the same as this rawscore, providing these semantics are satisfied.';


--
-- Name: COLUMN analysisfeature.significance; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysisfeature.significance IS 'This is some kind of expectation or probability metric, representing the probability that the analysis would appear randomly given the model. As such, any program or person querying this table can assume the following semantics:
   * 0 <= significance <= n, where n is a positive number, theoretically unbounded but unlikely to be more than 10
  * low numbers are better than high numbers.';


--
-- Name: COLUMN analysisfeature.identity; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.analysisfeature.identity IS 'Percent identity between the locations compared.  Note that these 4 metrics do not cover the full range of scores possible; it would be undesirable to list every score possible, as this should be kept extensible. instead, for non-standard scores, use the analysisprop table.';


--
-- Name: analysisfeature_analysisfeature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysisfeature_analysisfeature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysisfeature_analysisfeature_id_seq OWNER TO www;

--
-- Name: analysisfeature_analysisfeature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysisfeature_analysisfeature_id_seq OWNED BY chado.analysisfeature.analysisfeature_id;


--
-- Name: analysisfeatureprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysisfeatureprop (
    analysisfeatureprop_id bigint NOT NULL,
    analysisfeature_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer NOT NULL
);


ALTER TABLE chado.analysisfeatureprop OWNER TO www;

--
-- Name: analysisfeatureprop_analysisfeatureprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysisfeatureprop_analysisfeatureprop_id_seq OWNER TO www;

--
-- Name: analysisfeatureprop_analysisfeatureprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq OWNED BY chado.analysisfeatureprop.analysisfeatureprop_id;


--
-- Name: analysisprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.analysisprop (
    analysisprop_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.analysisprop OWNER TO www;

--
-- Name: analysisprop_analysisprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.analysisprop_analysisprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.analysisprop_analysisprop_id_seq OWNER TO www;

--
-- Name: analysisprop_analysisprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.analysisprop_analysisprop_id_seq OWNED BY chado.analysisprop.analysisprop_id;


--
-- Name: arraydesign; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.arraydesign (
    arraydesign_id bigint NOT NULL,
    manufacturer_id bigint NOT NULL,
    platformtype_id bigint NOT NULL,
    substratetype_id bigint,
    protocol_id bigint,
    dbxref_id bigint,
    name text NOT NULL,
    version text,
    description text,
    array_dimensions text,
    element_dimensions text,
    num_of_elements integer,
    num_array_columns integer,
    num_array_rows integer,
    num_grid_columns integer,
    num_grid_rows integer,
    num_sub_columns integer,
    num_sub_rows integer
);


ALTER TABLE chado.arraydesign OWNER TO www;

--
-- Name: TABLE arraydesign; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.arraydesign IS 'General properties about an array.
An array is a template used to generate physical slides, etc.  It
contains layout information, as well as global array properties, such
as material (glass, nylon) and spot dimensions (in rows/columns).';


--
-- Name: arraydesign_arraydesign_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.arraydesign_arraydesign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.arraydesign_arraydesign_id_seq OWNER TO www;

--
-- Name: arraydesign_arraydesign_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.arraydesign_arraydesign_id_seq OWNED BY chado.arraydesign.arraydesign_id;


--
-- Name: arraydesignprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.arraydesignprop (
    arraydesignprop_id bigint NOT NULL,
    arraydesign_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.arraydesignprop OWNER TO www;

--
-- Name: TABLE arraydesignprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.arraydesignprop IS 'Extra array design properties that are not accounted for in arraydesign.';


--
-- Name: arraydesignprop_arraydesignprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.arraydesignprop_arraydesignprop_id_seq OWNER TO www;

--
-- Name: arraydesignprop_arraydesignprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq OWNED BY chado.arraydesignprop.arraydesignprop_id;


--
-- Name: assay; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.assay (
    assay_id bigint NOT NULL,
    arraydesign_id bigint NOT NULL,
    protocol_id bigint,
    assaydate timestamp without time zone DEFAULT now(),
    arrayidentifier text,
    arraybatchidentifier text,
    operator_id bigint NOT NULL,
    dbxref_id bigint,
    name text,
    description text
);


ALTER TABLE chado.assay OWNER TO www;

--
-- Name: TABLE assay; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.assay IS 'An assay consists of a physical instance of
an array, combined with the conditions used to create the array
(protocols, technician information). The assay can be thought of as a hybridization.';


--
-- Name: assay_assay_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.assay_assay_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.assay_assay_id_seq OWNER TO www;

--
-- Name: assay_assay_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.assay_assay_id_seq OWNED BY chado.assay.assay_id;


--
-- Name: assay_biomaterial; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.assay_biomaterial (
    assay_biomaterial_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    biomaterial_id bigint NOT NULL,
    channel_id bigint,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.assay_biomaterial OWNER TO www;

--
-- Name: TABLE assay_biomaterial; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.assay_biomaterial IS 'A biomaterial can be hybridized many times (technical replicates), or combined with other biomaterials in a single hybridization (for two-channel arrays).';


--
-- Name: assay_biomaterial_assay_biomaterial_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.assay_biomaterial_assay_biomaterial_id_seq OWNER TO www;

--
-- Name: assay_biomaterial_assay_biomaterial_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq OWNED BY chado.assay_biomaterial.assay_biomaterial_id;


--
-- Name: assay_project; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.assay_project (
    assay_project_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    project_id bigint NOT NULL
);


ALTER TABLE chado.assay_project OWNER TO www;

--
-- Name: TABLE assay_project; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.assay_project IS 'Link assays to projects.';


--
-- Name: assay_project_assay_project_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.assay_project_assay_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.assay_project_assay_project_id_seq OWNER TO www;

--
-- Name: assay_project_assay_project_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.assay_project_assay_project_id_seq OWNED BY chado.assay_project.assay_project_id;


--
-- Name: assayprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.assayprop (
    assayprop_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.assayprop OWNER TO www;

--
-- Name: TABLE assayprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.assayprop IS 'Extra assay properties that are not accounted for in assay.';


--
-- Name: assayprop_assayprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.assayprop_assayprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.assayprop_assayprop_id_seq OWNER TO www;

--
-- Name: assayprop_assayprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.assayprop_assayprop_id_seq OWNED BY chado.assayprop.assayprop_id;


--
-- Name: biomaterial; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.biomaterial (
    biomaterial_id bigint NOT NULL,
    taxon_id bigint,
    biosourceprovider_id bigint,
    dbxref_id bigint,
    name text,
    description text
);


ALTER TABLE chado.biomaterial OWNER TO www;

--
-- Name: TABLE biomaterial; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.biomaterial IS 'A biomaterial represents the MAGE concept of BioSource, BioSample, and LabeledExtract. It is essentially some biological material (tissue, cells, serum) that may have been processed. Processed biomaterials should be traceable back to raw biomaterials via the biomaterialrelationship table.';


--
-- Name: biomaterial_biomaterial_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.biomaterial_biomaterial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.biomaterial_biomaterial_id_seq OWNER TO www;

--
-- Name: biomaterial_biomaterial_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.biomaterial_biomaterial_id_seq OWNED BY chado.biomaterial.biomaterial_id;


--
-- Name: biomaterial_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.biomaterial_dbxref (
    biomaterial_dbxref_id bigint NOT NULL,
    biomaterial_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.biomaterial_dbxref OWNER TO www;

--
-- Name: biomaterial_dbxref_biomaterial_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq OWNER TO www;

--
-- Name: biomaterial_dbxref_biomaterial_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq OWNED BY chado.biomaterial_dbxref.biomaterial_dbxref_id;


--
-- Name: biomaterial_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.biomaterial_relationship (
    biomaterial_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    type_id bigint NOT NULL,
    object_id bigint NOT NULL
);


ALTER TABLE chado.biomaterial_relationship OWNER TO www;

--
-- Name: TABLE biomaterial_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.biomaterial_relationship IS 'Relate biomaterials to one another. This is a way to track a series of treatments or material splits/merges, for instance.';


--
-- Name: biomaterial_relationship_biomaterial_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.biomaterial_relationship_biomaterial_relationship_id_seq OWNER TO www;

--
-- Name: biomaterial_relationship_biomaterial_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq OWNED BY chado.biomaterial_relationship.biomaterial_relationship_id;


--
-- Name: biomaterial_treatment; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.biomaterial_treatment (
    biomaterial_treatment_id bigint NOT NULL,
    biomaterial_id bigint NOT NULL,
    treatment_id bigint NOT NULL,
    unittype_id bigint,
    value real,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.biomaterial_treatment OWNER TO www;

--
-- Name: TABLE biomaterial_treatment; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.biomaterial_treatment IS 'Link biomaterials to treatments. Treatments have an order of operations (rank), and associated measurements (unittype_id, value).';


--
-- Name: biomaterial_treatment_biomaterial_treatment_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.biomaterial_treatment_biomaterial_treatment_id_seq OWNER TO www;

--
-- Name: biomaterial_treatment_biomaterial_treatment_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq OWNED BY chado.biomaterial_treatment.biomaterial_treatment_id;


--
-- Name: biomaterialprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.biomaterialprop (
    biomaterialprop_id bigint NOT NULL,
    biomaterial_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.biomaterialprop OWNER TO www;

--
-- Name: TABLE biomaterialprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.biomaterialprop IS 'Extra biomaterial properties that are not accounted for in biomaterial.';


--
-- Name: biomaterialprop_biomaterialprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.biomaterialprop_biomaterialprop_id_seq OWNER TO www;

--
-- Name: biomaterialprop_biomaterialprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq OWNED BY chado.biomaterialprop.biomaterialprop_id;


--
-- Name: blast_hit_data; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.blast_hit_data (
    analysisfeature_id integer NOT NULL,
    analysis_id integer NOT NULL,
    feature_id integer NOT NULL,
    db_id integer NOT NULL,
    hit_num integer NOT NULL,
    hit_name character varying(1025),
    hit_url text,
    hit_description text,
    hit_organism character varying(1025),
    blast_org_id integer,
    hit_accession character varying(255),
    hit_best_eval double precision,
    hit_best_score double precision,
    hit_pid double precision
);


ALTER TABLE chado.blast_hit_data OWNER TO www;

--
-- Name: blast_organisms; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.blast_organisms (
    blast_org_id integer NOT NULL,
    blast_org_name character varying(1025)
);


ALTER TABLE chado.blast_organisms OWNER TO www;

--
-- Name: blast_organisms_blast_org_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.blast_organisms_blast_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.blast_organisms_blast_org_id_seq OWNER TO www;

--
-- Name: blast_organisms_blast_org_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.blast_organisms_blast_org_id_seq OWNED BY chado.blast_organisms.blast_org_id;


--
-- Name: cell_line; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line (
    cell_line_id bigint NOT NULL,
    name character varying(255),
    uniquename character varying(255) NOT NULL,
    organism_id bigint NOT NULL,
    timeaccessioned timestamp without time zone DEFAULT now() NOT NULL,
    timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE chado.cell_line OWNER TO www;

--
-- Name: cell_line_cell_line_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_cell_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_cell_line_id_seq OWNER TO www;

--
-- Name: cell_line_cell_line_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_cell_line_id_seq OWNED BY chado.cell_line.cell_line_id;


--
-- Name: cell_line_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_cvterm (
    cell_line_cvterm_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cell_line_cvterm OWNER TO www;

--
-- Name: cell_line_cvterm_cell_line_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_cvterm_cell_line_cvterm_id_seq OWNER TO www;

--
-- Name: cell_line_cvterm_cell_line_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq OWNED BY chado.cell_line_cvterm.cell_line_cvterm_id;


--
-- Name: cell_line_cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_cvtermprop (
    cell_line_cvtermprop_id bigint NOT NULL,
    cell_line_cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cell_line_cvtermprop OWNER TO www;

--
-- Name: cell_line_cvtermprop_cell_line_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq OWNER TO www;

--
-- Name: cell_line_cvtermprop_cell_line_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq OWNED BY chado.cell_line_cvtermprop.cell_line_cvtermprop_id;


--
-- Name: cell_line_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_dbxref (
    cell_line_dbxref_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.cell_line_dbxref OWNER TO www;

--
-- Name: cell_line_dbxref_cell_line_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_dbxref_cell_line_dbxref_id_seq OWNER TO www;

--
-- Name: cell_line_dbxref_cell_line_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq OWNED BY chado.cell_line_dbxref.cell_line_dbxref_id;


--
-- Name: cell_line_feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_feature (
    cell_line_feature_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.cell_line_feature OWNER TO www;

--
-- Name: cell_line_feature_cell_line_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_feature_cell_line_feature_id_seq OWNER TO www;

--
-- Name: cell_line_feature_cell_line_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq OWNED BY chado.cell_line_feature.cell_line_feature_id;


--
-- Name: cell_line_library; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_library (
    cell_line_library_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    library_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.cell_line_library OWNER TO www;

--
-- Name: cell_line_library_cell_line_library_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_library_cell_line_library_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_library_cell_line_library_id_seq OWNER TO www;

--
-- Name: cell_line_library_cell_line_library_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_library_cell_line_library_id_seq OWNED BY chado.cell_line_library.cell_line_library_id;


--
-- Name: cell_line_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_pub (
    cell_line_pub_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.cell_line_pub OWNER TO www;

--
-- Name: cell_line_pub_cell_line_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_pub_cell_line_pub_id_seq OWNER TO www;

--
-- Name: cell_line_pub_cell_line_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq OWNED BY chado.cell_line_pub.cell_line_pub_id;


--
-- Name: cell_line_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_relationship (
    cell_line_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.cell_line_relationship OWNER TO www;

--
-- Name: cell_line_relationship_cell_line_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_relationship_cell_line_relationship_id_seq OWNER TO www;

--
-- Name: cell_line_relationship_cell_line_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq OWNED BY chado.cell_line_relationship.cell_line_relationship_id;


--
-- Name: cell_line_synonym; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_line_synonym (
    cell_line_synonym_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    synonym_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    is_internal boolean DEFAULT false NOT NULL
);


ALTER TABLE chado.cell_line_synonym OWNER TO www;

--
-- Name: cell_line_synonym_cell_line_synonym_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_line_synonym_cell_line_synonym_id_seq OWNER TO www;

--
-- Name: cell_line_synonym_cell_line_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq OWNED BY chado.cell_line_synonym.cell_line_synonym_id;


--
-- Name: cell_lineprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_lineprop (
    cell_lineprop_id bigint NOT NULL,
    cell_line_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cell_lineprop OWNER TO www;

--
-- Name: cell_lineprop_cell_lineprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_lineprop_cell_lineprop_id_seq OWNER TO www;

--
-- Name: cell_lineprop_cell_lineprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq OWNED BY chado.cell_lineprop.cell_lineprop_id;


--
-- Name: cell_lineprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cell_lineprop_pub (
    cell_lineprop_pub_id bigint NOT NULL,
    cell_lineprop_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.cell_lineprop_pub OWNER TO www;

--
-- Name: cell_lineprop_pub_cell_lineprop_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq OWNER TO www;

--
-- Name: cell_lineprop_pub_cell_lineprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq OWNED BY chado.cell_lineprop_pub.cell_lineprop_pub_id;


--
-- Name: chado_gene; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.chado_gene (
    vid bigint DEFAULT 0 NOT NULL,
    nid bigint DEFAULT 0 NOT NULL,
    gene_id integer NOT NULL,
    CONSTRAINT chado_gene_nid_check CHECK ((nid >= 0)),
    CONSTRAINT chado_gene_vid_check CHECK ((vid >= 0))
);


ALTER TABLE chado.chado_gene OWNER TO www;

--
-- Name: chadoprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.chadoprop (
    chadoprop_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.chadoprop OWNER TO www;

--
-- Name: TABLE chadoprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.chadoprop IS 'This table is different from other prop tables in the database, as it is for storing information about the database itself, like schema version';


--
-- Name: COLUMN chadoprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.chadoprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN chadoprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.chadoprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN chadoprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.chadoprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: chadoprop_chadoprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.chadoprop_chadoprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.chadoprop_chadoprop_id_seq OWNER TO www;

--
-- Name: chadoprop_chadoprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.chadoprop_chadoprop_id_seq OWNED BY chado.chadoprop.chadoprop_id;


--
-- Name: channel; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.channel (
    channel_id bigint NOT NULL,
    name text NOT NULL,
    definition text NOT NULL
);


ALTER TABLE chado.channel OWNER TO www;

--
-- Name: TABLE channel; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.channel IS 'Different array platforms can record signals from one or more channels (cDNA arrays typically use two CCD, but Affymetrix uses only one).';


--
-- Name: channel_channel_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.channel_channel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.channel_channel_id_seq OWNER TO www;

--
-- Name: channel_channel_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.channel_channel_id_seq OWNED BY chado.channel.channel_id;


--
-- Name: common_ancestor_cvterm; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.common_ancestor_cvterm AS
 SELECT p1.subject_id AS cvterm1_id,
    p2.subject_id AS cvterm2_id,
    p1.object_id AS ancestor_cvterm_id,
    p1.pathdistance AS pathdistance1,
    p2.pathdistance AS pathdistance2,
    (p1.pathdistance + p2.pathdistance) AS total_pathdistance
   FROM chado.cvtermpath p1,
    chado.cvtermpath p2
  WHERE (p1.object_id = p2.object_id);


ALTER TABLE chado.common_ancestor_cvterm OWNER TO www;

--
-- Name: VIEW common_ancestor_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.common_ancestor_cvterm IS 'The common ancestor of any
two terms is the intersection of both terms ancestors. Two terms can
have multiple common ancestors. Use total_pathdistance to get the
least common ancestor';


--
-- Name: common_descendant_cvterm; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.common_descendant_cvterm AS
 SELECT p1.object_id AS cvterm1_id,
    p2.object_id AS cvterm2_id,
    p1.subject_id AS ancestor_cvterm_id,
    p1.pathdistance AS pathdistance1,
    p2.pathdistance AS pathdistance2,
    (p1.pathdistance + p2.pathdistance) AS total_pathdistance
   FROM chado.cvtermpath p1,
    chado.cvtermpath p2
  WHERE (p1.subject_id = p2.subject_id);


ALTER TABLE chado.common_descendant_cvterm OWNER TO www;

--
-- Name: VIEW common_descendant_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.common_descendant_cvterm IS 'The common descendant of
any two terms is the intersection of both terms descendants. Two terms
can have multiple common descendants. Use total_pathdistance to get
the least common ancestor';


--
-- Name: contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.contact (
    contact_id bigint NOT NULL,
    type_id bigint,
    name character varying(255) NOT NULL,
    description character varying(255)
);


ALTER TABLE chado.contact OWNER TO www;

--
-- Name: TABLE contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.contact IS 'Model persons, institutes, groups, organizations, etc.';


--
-- Name: COLUMN contact.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.contact.type_id IS 'What type of contact is this?  E.g. "person", "lab".';


--
-- Name: contact_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.contact_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.contact_contact_id_seq OWNER TO www;

--
-- Name: contact_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.contact_contact_id_seq OWNED BY chado.contact.contact_id;


--
-- Name: contact_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.contact_relationship (
    contact_relationship_id bigint NOT NULL,
    type_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL
);


ALTER TABLE chado.contact_relationship OWNER TO www;

--
-- Name: TABLE contact_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.contact_relationship IS 'Model relationships between contacts';


--
-- Name: COLUMN contact_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.contact_relationship.type_id IS 'Relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed.';


--
-- Name: COLUMN contact_relationship.subject_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.contact_relationship.subject_id IS 'The subject of the subj-predicate-obj sentence. In a DAG, this corresponds to the child node.';


--
-- Name: COLUMN contact_relationship.object_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.contact_relationship.object_id IS 'The object of the subj-predicate-obj sentence. In a DAG, this corresponds to the parent node.';


--
-- Name: contact_relationship_contact_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.contact_relationship_contact_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.contact_relationship_contact_relationship_id_seq OWNER TO www;

--
-- Name: contact_relationship_contact_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.contact_relationship_contact_relationship_id_seq OWNED BY chado.contact_relationship.contact_relationship_id;


--
-- Name: contactprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.contactprop (
    contactprop_id bigint NOT NULL,
    contact_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.contactprop OWNER TO www;

--
-- Name: TABLE contactprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.contactprop IS 'A contact can have any number of slot-value property 
tags attached to it. This is an alternative to hardcoding a list of columns in the 
relational schema, and is completely extensible.';


--
-- Name: contactprop_contactprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.contactprop_contactprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.contactprop_contactprop_id_seq OWNER TO www;

--
-- Name: contactprop_contactprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.contactprop_contactprop_id_seq OWNED BY chado.contactprop.contactprop_id;


--
-- Name: control; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.control (
    control_id bigint NOT NULL,
    type_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    tableinfo_id bigint NOT NULL,
    row_id integer NOT NULL,
    name text,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.control OWNER TO www;

--
-- Name: control_control_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.control_control_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.control_control_id_seq OWNER TO www;

--
-- Name: control_control_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.control_control_id_seq OWNED BY chado.control.control_id;


--
-- Name: cv; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cv (
    cv_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    definition text
);


ALTER TABLE chado.cv OWNER TO www;

--
-- Name: TABLE cv; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cv IS 'A controlled vocabulary or ontology. A cv is
composed of cvterms (AKA terms, classes, types, universals - relations
and properties are also stored in cvterm) and the relationships
between them.';


--
-- Name: COLUMN cv.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cv.name IS 'The name of the ontology. This
corresponds to the obo-format -namespace-. cv names uniquely identify
the cv. In OBO file format, the cv.name is known as the namespace.';


--
-- Name: COLUMN cv.definition; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cv.definition IS 'A text description of the criteria for
membership of this ontology.';


--
-- Name: cv_cv_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cv_cv_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cv_cv_id_seq OWNER TO www;

--
-- Name: cv_cv_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cv_cv_id_seq OWNED BY chado.cv.cv_id;


--
-- Name: cv_cvterm_count; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_cvterm_count AS
 SELECT cv.name,
    count(*) AS num_terms_excl_obs
   FROM (chado.cv
     JOIN chado.cvterm USING (cv_id))
  WHERE (cvterm.is_obsolete = 0)
  GROUP BY cv.name;


ALTER TABLE chado.cv_cvterm_count OWNER TO www;

--
-- Name: VIEW cv_cvterm_count; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_cvterm_count IS 'per-cv terms counts (excludes obsoletes)';


--
-- Name: cv_cvterm_count_with_obs; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_cvterm_count_with_obs AS
 SELECT cv.name,
    count(*) AS num_terms_incl_obs
   FROM (chado.cv
     JOIN chado.cvterm USING (cv_id))
  GROUP BY cv.name;


ALTER TABLE chado.cv_cvterm_count_with_obs OWNER TO www;

--
-- Name: VIEW cv_cvterm_count_with_obs; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_cvterm_count_with_obs IS 'per-cv terms counts (includes obsoletes)';


--
-- Name: cvterm_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvterm_relationship (
    cvterm_relationship_id bigint NOT NULL,
    type_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL
);


ALTER TABLE chado.cvterm_relationship OWNER TO www;

--
-- Name: TABLE cvterm_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvterm_relationship IS 'A relationship linking two
cvterms. Each cvterm_relationship constitutes an edge in the graph
defined by the collection of cvterms and cvterm_relationships. The
meaning of the cvterm_relationship depends on the definition of the
cvterm R refered to by type_id. However, in general the definitions
are such that the statement "all SUBJs REL some OBJ" is true. The
cvterm_relationship statement is about the subject, not the
object. For example "insect wing part_of thorax".';


--
-- Name: COLUMN cvterm_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm_relationship.type_id IS 'The nature of the
relationship between subject and object. Note that relations are also
housed in the cvterm table, typically from the OBO relationship
ontology, although other relationship types are allowed.';


--
-- Name: COLUMN cvterm_relationship.subject_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm_relationship.subject_id IS 'The subject of
the subj-predicate-obj sentence. The cvterm_relationship is about the
subject. In a graph, this typically corresponds to the child node.';


--
-- Name: COLUMN cvterm_relationship.object_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm_relationship.object_id IS 'The object of the
subj-predicate-obj sentence. The cvterm_relationship refers to the
object. In a graph, this typically corresponds to the parent node.';


--
-- Name: cv_leaf; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_leaf AS
 SELECT cvterm.cv_id,
    cvterm.cvterm_id
   FROM chado.cvterm
  WHERE (NOT (cvterm.cvterm_id IN ( SELECT cvterm_relationship.object_id
           FROM chado.cvterm_relationship)));


ALTER TABLE chado.cv_leaf OWNER TO www;

--
-- Name: VIEW cv_leaf; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_leaf IS 'the leaves of a cv are the set of terms
which have no children (terms that are not the object of a
relation). All cvs will have at least 1 leaf';


--
-- Name: cv_link_count; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_link_count AS
 SELECT cv.name AS cv_name,
    relation.name AS relation_name,
    relation_cv.name AS relation_cv_name,
    count(*) AS num_links
   FROM ((((chado.cv
     JOIN chado.cvterm ON ((cvterm.cv_id = cv.cv_id)))
     JOIN chado.cvterm_relationship ON ((cvterm.cvterm_id = cvterm_relationship.subject_id)))
     JOIN chado.cvterm relation ON ((cvterm_relationship.type_id = relation.cvterm_id)))
     JOIN chado.cv relation_cv ON ((relation.cv_id = relation_cv.cv_id)))
  GROUP BY cv.name, relation.name, relation_cv.name;


ALTER TABLE chado.cv_link_count OWNER TO www;

--
-- Name: VIEW cv_link_count; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_link_count IS 'per-cv summary of number of
links (cvterm_relationships) broken down by
relationship_type. num_links is the total # of links of the specified
type in which the subject_id of the link is in the named cv';


--
-- Name: cv_path_count; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_path_count AS
 SELECT cv.name AS cv_name,
    relation.name AS relation_name,
    relation_cv.name AS relation_cv_name,
    count(*) AS num_paths
   FROM ((((chado.cv
     JOIN chado.cvterm ON ((cvterm.cv_id = cv.cv_id)))
     JOIN chado.cvtermpath ON ((cvterm.cvterm_id = cvtermpath.subject_id)))
     JOIN chado.cvterm relation ON ((cvtermpath.type_id = relation.cvterm_id)))
     JOIN chado.cv relation_cv ON ((relation.cv_id = relation_cv.cv_id)))
  GROUP BY cv.name, relation.name, relation_cv.name;


ALTER TABLE chado.cv_path_count OWNER TO www;

--
-- Name: VIEW cv_path_count; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_path_count IS 'per-cv summary of number of
paths (cvtermpaths) broken down by relationship_type. num_paths is the
total # of paths of the specified type in which the subject_id of the
path is in the named cv. See also: cv_distinct_relations';


--
-- Name: cv_root; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.cv_root AS
 SELECT cvterm.cv_id,
    cvterm.cvterm_id AS root_cvterm_id
   FROM chado.cvterm
  WHERE ((NOT (cvterm.cvterm_id IN ( SELECT cvterm_relationship.subject_id
           FROM chado.cvterm_relationship))) AND (cvterm.is_obsolete = 0));


ALTER TABLE chado.cv_root OWNER TO www;

--
-- Name: VIEW cv_root; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.cv_root IS 'the roots of a cv are the set of terms
which have no parents (terms that are not the subject of a
relation). Most cvs will have a single root, some may have >1. All
will have at least 1';


--
-- Name: cv_root_mview; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cv_root_mview (
    name character varying(1024),
    cvterm_id integer,
    cv_id integer,
    cv_name character varying(255)
);


ALTER TABLE chado.cv_root_mview OWNER TO www;

--
-- Name: cvprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvprop (
    cvprop_id bigint NOT NULL,
    cv_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cvprop OWNER TO www;

--
-- Name: TABLE cvprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvprop IS 'Additional extensible properties can be attached to a cv using this table.  A notable example would be the cv version';


--
-- Name: COLUMN cvprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN cvprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN cvprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvprop.rank IS 'Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: cvprop_cvprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvprop_cvprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvprop_cvprop_id_seq OWNER TO www;

--
-- Name: cvprop_cvprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvprop_cvprop_id_seq OWNED BY chado.cvprop.cvprop_id;


--
-- Name: cvterm_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvterm_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvterm_cvterm_id_seq OWNER TO www;

--
-- Name: cvterm_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvterm_cvterm_id_seq OWNED BY chado.cvterm.cvterm_id;


--
-- Name: cvterm_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvterm_dbxref (
    cvterm_dbxref_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_for_definition integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cvterm_dbxref OWNER TO www;

--
-- Name: TABLE cvterm_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvterm_dbxref IS 'In addition to the primary
identifier (cvterm.dbxref_id) a cvterm can have zero or more secondary
identifiers/dbxrefs, which may refer to records in external
databases. The exact semantics of cvterm_dbxref are not fixed. For
example: the dbxref could be a pubmed ID that is pertinent to the
cvterm, or it could be an equivalent or similar term in another
ontology. For example, GO cvterms are typically linked to InterPro
IDs, even though the nature of the relationship between them is
largely one of statistical association. The dbxref may be have data
records attached in the same database instance, or it could be a
"hanging" dbxref pointing to some external database. NOTE: If the
desired objective is to link two cvterms together, and the nature of
the relation is known and holds for all instances of the subject
cvterm then consider instead using cvterm_relationship together with a
well-defined relation.';


--
-- Name: COLUMN cvterm_dbxref.is_for_definition; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvterm_dbxref.is_for_definition IS 'A
cvterm.definition should be supported by one or more references. If
this column is true, the dbxref is not for a term in an external database -
it is a dbxref for provenance information for the definition.';


--
-- Name: cvterm_dbxref_cvterm_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvterm_dbxref_cvterm_dbxref_id_seq OWNER TO www;

--
-- Name: cvterm_dbxref_cvterm_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq OWNED BY chado.cvterm_dbxref.cvterm_dbxref_id;


--
-- Name: cvterm_relationship_cvterm_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvterm_relationship_cvterm_relationship_id_seq OWNER TO www;

--
-- Name: cvterm_relationship_cvterm_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq OWNED BY chado.cvterm_relationship.cvterm_relationship_id;


--
-- Name: cvtermpath_cvtermpath_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvtermpath_cvtermpath_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvtermpath_cvtermpath_id_seq OWNER TO www;

--
-- Name: cvtermpath_cvtermpath_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvtermpath_cvtermpath_id_seq OWNED BY chado.cvtermpath.cvtermpath_id;


--
-- Name: cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvtermprop (
    cvtermprop_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.cvtermprop OWNER TO www;

--
-- Name: TABLE cvtermprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvtermprop IS 'Additional extensible properties can be attached to a cvterm using this table. Corresponds to -AnnotationProperty- in W3C OWL format.';


--
-- Name: COLUMN cvtermprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermprop.type_id IS 'The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN cvtermprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermprop.value IS 'The value of the property, represented as text. Numeric values are converted to their text representation.';


--
-- Name: COLUMN cvtermprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermprop.rank IS 'Property-Value ordering. Any
cvterm can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.';


--
-- Name: cvtermprop_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvtermprop_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvtermprop_cvtermprop_id_seq OWNER TO www;

--
-- Name: cvtermprop_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvtermprop_cvtermprop_id_seq OWNED BY chado.cvtermprop.cvtermprop_id;


--
-- Name: cvtermsynonym; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.cvtermsynonym (
    cvtermsynonym_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    synonym character varying(1024) NOT NULL,
    type_id bigint
);


ALTER TABLE chado.cvtermsynonym OWNER TO www;

--
-- Name: TABLE cvtermsynonym; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.cvtermsynonym IS 'A cvterm actually represents a
distinct class or concept. A concept can be refered to by different
phrases or names. In addition to the primary name (cvterm.name) there
can be a number of alternative aliases or synonyms. For example, "T
cell" as a synonym for "T lymphocyte".';


--
-- Name: COLUMN cvtermsynonym.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.cvtermsynonym.type_id IS 'A synonym can be exact,
narrower, or broader than.';


--
-- Name: cvtermsynonym_cvtermsynonym_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.cvtermsynonym_cvtermsynonym_id_seq OWNER TO www;

--
-- Name: cvtermsynonym_cvtermsynonym_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq OWNED BY chado.cvtermsynonym.cvtermsynonym_id;


--
-- Name: db_db_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.db_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.db_db_id_seq OWNER TO www;

--
-- Name: db_db_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.db_db_id_seq OWNED BY chado.db.db_id;


--
-- Name: db_dbxref_count; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.db_dbxref_count AS
 SELECT db.name,
    count(*) AS num_dbxrefs
   FROM (chado.db
     JOIN chado.dbxref USING (db_id))
  GROUP BY db.name;


ALTER TABLE chado.db_dbxref_count OWNER TO www;

--
-- Name: VIEW db_dbxref_count; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.db_dbxref_count IS 'per-db dbxref counts';


--
-- Name: dbprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.dbprop (
    dbprop_id bigint NOT NULL,
    db_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.dbprop OWNER TO www;

--
-- Name: TABLE dbprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.dbprop IS 'An external database can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, dbprop_c1, for
the combination of db_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: dbprop_dbprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.dbprop_dbprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.dbprop_dbprop_id_seq OWNER TO www;

--
-- Name: dbprop_dbprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.dbprop_dbprop_id_seq OWNED BY chado.dbprop.dbprop_id;


--
-- Name: dbxref_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.dbxref_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.dbxref_dbxref_id_seq OWNER TO www;

--
-- Name: dbxref_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.dbxref_dbxref_id_seq OWNED BY chado.dbxref.dbxref_id;


--
-- Name: dbxrefprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.dbxrefprop (
    dbxrefprop_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.dbxrefprop OWNER TO www;

--
-- Name: TABLE dbxrefprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.dbxrefprop IS 'Metadata about a dbxref. Note that this is not defined in the dbxref module, as it depends on the cvterm table. This table has a structure analagous to cvtermprop.';


--
-- Name: dbxrefprop_dbxrefprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.dbxrefprop_dbxrefprop_id_seq OWNER TO www;

--
-- Name: dbxrefprop_dbxrefprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq OWNED BY chado.dbxrefprop.dbxrefprop_id;


--
-- Name: dfeatureloc; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.dfeatureloc AS
 SELECT featureloc.featureloc_id,
    featureloc.feature_id,
    featureloc.srcfeature_id,
    featureloc.fmin AS nbeg,
    featureloc.is_fmin_partial AS is_nbeg_partial,
    featureloc.fmax AS nend,
    featureloc.is_fmax_partial AS is_nend_partial,
    featureloc.strand,
    featureloc.phase,
    featureloc.residue_info,
    featureloc.locgroup,
    featureloc.rank
   FROM chado.featureloc
  WHERE ((featureloc.strand < 0) OR (featureloc.phase < 0))
UNION
 SELECT featureloc.featureloc_id,
    featureloc.feature_id,
    featureloc.srcfeature_id,
    featureloc.fmax AS nbeg,
    featureloc.is_fmax_partial AS is_nbeg_partial,
    featureloc.fmin AS nend,
    featureloc.is_fmin_partial AS is_nend_partial,
    featureloc.strand,
    featureloc.phase,
    featureloc.residue_info,
    featureloc.locgroup,
    featureloc.rank
   FROM chado.featureloc
  WHERE ((featureloc.strand IS NULL) OR (featureloc.strand >= 0) OR (featureloc.phase >= 0));


ALTER TABLE chado.dfeatureloc OWNER TO www;

--
-- Name: domain; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.domain (
    feature_feature_id integer NOT NULL,
    feature_name text,
    cvterm_name text,
    iprterm text,
    feature_desc text,
    total_count integer,
    arahy_count integer,
    aradu_count integer,
    araip_count integer
);


ALTER TABLE chado.domain OWNER TO www;

--
-- Name: eimage; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.eimage (
    eimage_id bigint NOT NULL,
    eimage_data text,
    eimage_type character varying(255) NOT NULL,
    image_uri character varying(255)
);


ALTER TABLE chado.eimage OWNER TO www;

--
-- Name: COLUMN eimage.eimage_data; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.eimage.eimage_data IS 'We expect images in eimage_data (e.g. JPEGs) to be uuencoded.';


--
-- Name: COLUMN eimage.eimage_type; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.eimage.eimage_type IS 'Describes the type of data in eimage_data.';


--
-- Name: eimage_eimage_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.eimage_eimage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.eimage_eimage_id_seq OWNER TO www;

--
-- Name: eimage_eimage_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.eimage_eimage_id_seq OWNED BY chado.eimage.eimage_id;


--
-- Name: element; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.element (
    element_id bigint NOT NULL,
    feature_id bigint,
    arraydesign_id bigint NOT NULL,
    type_id bigint,
    dbxref_id bigint
);


ALTER TABLE chado.element OWNER TO www;

--
-- Name: TABLE element; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.element IS 'Represents a feature of the array. This is typically a region of the array coated or bound to DNA.';


--
-- Name: element_element_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.element_element_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.element_element_id_seq OWNER TO www;

--
-- Name: element_element_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.element_element_id_seq OWNED BY chado.element.element_id;


--
-- Name: element_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.element_relationship (
    element_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    type_id bigint NOT NULL,
    object_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.element_relationship OWNER TO www;

--
-- Name: TABLE element_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.element_relationship IS 'Sometimes we want to combine measurements from multiple elements to get a composite value. Affymetrix combines many probes to form a probeset measurement, for instance.';


--
-- Name: element_relationship_element_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.element_relationship_element_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.element_relationship_element_relationship_id_seq OWNER TO www;

--
-- Name: element_relationship_element_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.element_relationship_element_relationship_id_seq OWNED BY chado.element_relationship.element_relationship_id;


--
-- Name: elementresult; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.elementresult (
    elementresult_id bigint NOT NULL,
    element_id bigint NOT NULL,
    quantification_id bigint NOT NULL,
    signal double precision NOT NULL
);


ALTER TABLE chado.elementresult OWNER TO www;

--
-- Name: TABLE elementresult; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.elementresult IS 'An element on an array produces a measurement when hybridized to a biomaterial (traceable through quantification_id). This is the base data from which tables that actually contain data inherit.';


--
-- Name: elementresult_elementresult_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.elementresult_elementresult_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.elementresult_elementresult_id_seq OWNER TO www;

--
-- Name: elementresult_elementresult_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.elementresult_elementresult_id_seq OWNED BY chado.elementresult.elementresult_id;


--
-- Name: elementresult_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.elementresult_relationship (
    elementresult_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    type_id bigint NOT NULL,
    object_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.elementresult_relationship OWNER TO www;

--
-- Name: TABLE elementresult_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.elementresult_relationship IS 'Sometimes we want to combine measurements from multiple elements to get a composite value. Affymetrix combines many probes to form a probeset measurement, for instance.';


--
-- Name: elementresult_relationship_elementresult_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.elementresult_relationship_elementresult_relationship_id_seq OWNER TO www;

--
-- Name: elementresult_relationship_elementresult_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq OWNED BY chado.elementresult_relationship.elementresult_relationship_id;


--
-- Name: environment; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.environment (
    environment_id bigint NOT NULL,
    uniquename text NOT NULL,
    description text
);


ALTER TABLE chado.environment OWNER TO www;

--
-- Name: TABLE environment; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.environment IS 'The environmental component of a phenotype description.';


--
-- Name: environment_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.environment_cvterm (
    environment_cvterm_id bigint NOT NULL,
    environment_id bigint NOT NULL,
    cvterm_id bigint NOT NULL
);


ALTER TABLE chado.environment_cvterm OWNER TO www;

--
-- Name: environment_cvterm_environment_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.environment_cvterm_environment_cvterm_id_seq OWNER TO www;

--
-- Name: environment_cvterm_environment_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq OWNED BY chado.environment_cvterm.environment_cvterm_id;


--
-- Name: environment_environment_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.environment_environment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.environment_environment_id_seq OWNER TO www;

--
-- Name: environment_environment_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.environment_environment_id_seq OWNED BY chado.environment.environment_id;


--
-- Name: expression; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expression (
    expression_id bigint NOT NULL,
    uniquename text NOT NULL,
    md5checksum character(32),
    description text
);


ALTER TABLE chado.expression OWNER TO www;

--
-- Name: TABLE expression; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.expression IS 'The expression table is essentially a bridge table.';


--
-- Name: expression_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expression_cvterm (
    expression_cvterm_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    cvterm_type_id bigint NOT NULL
);


ALTER TABLE chado.expression_cvterm OWNER TO www;

--
-- Name: expression_cvterm_expression_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expression_cvterm_expression_cvterm_id_seq OWNER TO www;

--
-- Name: expression_cvterm_expression_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq OWNED BY chado.expression_cvterm.expression_cvterm_id;


--
-- Name: expression_cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expression_cvtermprop (
    expression_cvtermprop_id bigint NOT NULL,
    expression_cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.expression_cvtermprop OWNER TO www;

--
-- Name: TABLE expression_cvtermprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.expression_cvtermprop IS 'Extensible properties for
expression to cvterm associations. Examples: qualifiers.';


--
-- Name: COLUMN expression_cvtermprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.expression_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. For example, cvterms may come from the FlyBase miscellaneous cv.';


--
-- Name: COLUMN expression_cvtermprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.expression_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN expression_cvtermprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.expression_cvtermprop.rank IS 'Property-Value
ordering. Any expression_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: expression_cvtermprop_expression_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expression_cvtermprop_expression_cvtermprop_id_seq OWNER TO www;

--
-- Name: expression_cvtermprop_expression_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq OWNED BY chado.expression_cvtermprop.expression_cvtermprop_id;


--
-- Name: expression_expression_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expression_expression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expression_expression_id_seq OWNER TO www;

--
-- Name: expression_expression_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expression_expression_id_seq OWNED BY chado.expression.expression_id;


--
-- Name: expression_image; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expression_image (
    expression_image_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    eimage_id bigint NOT NULL
);


ALTER TABLE chado.expression_image OWNER TO www;

--
-- Name: expression_image_expression_image_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expression_image_expression_image_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expression_image_expression_image_id_seq OWNER TO www;

--
-- Name: expression_image_expression_image_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expression_image_expression_image_id_seq OWNED BY chado.expression_image.expression_image_id;


--
-- Name: expression_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expression_pub (
    expression_pub_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.expression_pub OWNER TO www;

--
-- Name: expression_pub_expression_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expression_pub_expression_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expression_pub_expression_pub_id_seq OWNER TO www;

--
-- Name: expression_pub_expression_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expression_pub_expression_pub_id_seq OWNED BY chado.expression_pub.expression_pub_id;


--
-- Name: expressionprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.expressionprop (
    expressionprop_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.expressionprop OWNER TO www;

--
-- Name: expressionprop_expressionprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.expressionprop_expressionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.expressionprop_expressionprop_id_seq OWNER TO www;

--
-- Name: expressionprop_expressionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.expressionprop_expressionprop_id_seq OWNED BY chado.expressionprop.expressionprop_id;


--
-- Name: f_type; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.f_type AS
 SELECT f.feature_id,
    f.name,
    f.dbxref_id,
    c.name AS type,
    f.residues,
    f.seqlen,
    f.md5checksum,
    f.type_id,
    f.timeaccessioned,
    f.timelastmodified
   FROM chado.feature f,
    chado.cvterm c
  WHERE (f.type_id = c.cvterm_id);


ALTER TABLE chado.f_type OWNER TO www;

--
-- Name: f_loc; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.f_loc AS
 SELECT f.feature_id,
    f.name,
    f.dbxref_id,
    fl.nbeg,
    fl.nend,
    fl.strand
   FROM chado.dfeatureloc fl,
    chado.f_type f
  WHERE (f.feature_id = fl.feature_id);


ALTER TABLE chado.f_loc OWNER TO www;

--
-- Name: feature_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_contact (
    feature_contact_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    contact_id bigint NOT NULL
);


ALTER TABLE chado.feature_contact OWNER TO www;

--
-- Name: TABLE feature_contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_contact IS 'Links contact(s) with a feature.  Used to indicate a particular 
person or organization responsible for discovery or that can provide more information on a particular feature.';


--
-- Name: feature_contact_feature_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_contact_feature_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_contact_feature_contact_id_seq OWNER TO www;

--
-- Name: feature_contact_feature_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_contact_feature_contact_id_seq OWNED BY chado.feature_contact.feature_contact_id;


--
-- Name: feature_contains; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_contains AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((y.fmin >= x.fmin) AND (y.fmin <= x.fmax)));


ALTER TABLE chado.feature_contains OWNER TO www;

--
-- Name: VIEW feature_contains; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_contains IS 'subject intervals contains (or is
same as) object interval. transitive,reflexive';


--
-- Name: feature_cvterm_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_cvterm_dbxref (
    feature_cvterm_dbxref_id bigint NOT NULL,
    feature_cvterm_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.feature_cvterm_dbxref OWNER TO www;

--
-- Name: TABLE feature_cvterm_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_cvterm_dbxref IS 'Additional dbxrefs for an association. Rows in the feature_cvterm table may be backed up by dbxrefs. For example, a feature_cvterm association that was inferred via a protein-protein interaction may be backed by by refering to the dbxref for the alternate protein. Corresponds to the WITH column in a GO gene association file (but can also be used for other analagous associations). See http://www.geneontology.org/doc/GO.annotation.shtml#file for more details.';


--
-- Name: feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq OWNER TO www;

--
-- Name: feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq OWNED BY chado.feature_cvterm_dbxref.feature_cvterm_dbxref_id;


--
-- Name: feature_cvterm_feature_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_cvterm_feature_cvterm_id_seq OWNER TO www;

--
-- Name: feature_cvterm_feature_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq OWNED BY chado.feature_cvterm.feature_cvterm_id;


--
-- Name: feature_cvterm_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_cvterm_pub (
    feature_cvterm_pub_id bigint NOT NULL,
    feature_cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.feature_cvterm_pub OWNER TO www;

--
-- Name: TABLE feature_cvterm_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_cvterm_pub IS 'Secondary pubs for an
association. Each feature_cvterm association is supported by a single
primary publication. Additional secondary pubs can be added using this
linking table (in a GO gene association file, these corresponding to
any IDs after the pipe symbol in the publications column.';


--
-- Name: feature_cvterm_pub_feature_cvterm_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq OWNER TO www;

--
-- Name: feature_cvterm_pub_feature_cvterm_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq OWNED BY chado.feature_cvterm_pub.feature_cvterm_pub_id;


--
-- Name: feature_cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_cvtermprop (
    feature_cvtermprop_id bigint NOT NULL,
    feature_cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_cvtermprop OWNER TO www;

--
-- Name: TABLE feature_cvtermprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_cvtermprop IS 'Extensible properties for
feature to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the featureprop table for
meanings of type_id, value and rank.';


--
-- Name: COLUMN feature_cvtermprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.';


--
-- Name: COLUMN feature_cvtermprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN feature_cvtermprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_cvtermprop.rank IS 'Property-Value
ordering. Any feature_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: feature_cvtermprop_feature_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_cvtermprop_feature_cvtermprop_id_seq OWNER TO www;

--
-- Name: feature_cvtermprop_feature_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq OWNED BY chado.feature_cvtermprop.feature_cvtermprop_id;


--
-- Name: feature_dbxref_feature_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_dbxref_feature_dbxref_id_seq OWNER TO www;

--
-- Name: feature_dbxref_feature_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq OWNED BY chado.feature_dbxref.feature_dbxref_id;


--
-- Name: feature_difference; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_difference AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id,
    x.strand AS srcfeature_id,
    x.srcfeature_id AS fmin,
    x.fmin AS fmax,
    y.fmin AS strand
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmin < y.fmin) AND (x.fmax >= y.fmax)))
UNION
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id,
    x.strand AS srcfeature_id,
    x.srcfeature_id AS fmin,
    y.fmax,
    x.fmax AS strand
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax > y.fmax) AND (x.fmin <= y.fmin)));


ALTER TABLE chado.feature_difference OWNER TO www;

--
-- Name: VIEW feature_difference; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_difference IS 'size of gap between two features. must be abutting or disjoint';


--
-- Name: feature_disjoint; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_disjoint AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax < y.fmin) AND (x.fmin > y.fmax)));


ALTER TABLE chado.feature_disjoint OWNER TO www;

--
-- Name: VIEW feature_disjoint; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_disjoint IS 'featurelocs do not meet. symmetric';


--
-- Name: feature_distance; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_distance AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id,
    x.srcfeature_id,
    x.strand AS subject_strand,
    y.strand AS object_strand,
        CASE
            WHEN (x.fmax <= y.fmin) THEN (x.fmax - y.fmin)
            ELSE (y.fmax - x.fmin)
        END AS distance
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax <= y.fmin) OR (x.fmin >= y.fmax)));


ALTER TABLE chado.feature_distance OWNER TO www;

--
-- Name: feature_expression; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_expression (
    feature_expression_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.feature_expression OWNER TO www;

--
-- Name: feature_expression_feature_expression_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_expression_feature_expression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_expression_feature_expression_id_seq OWNER TO www;

--
-- Name: feature_expression_feature_expression_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_expression_feature_expression_id_seq OWNED BY chado.feature_expression.feature_expression_id;


--
-- Name: feature_expressionprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_expressionprop (
    feature_expressionprop_id bigint NOT NULL,
    feature_expression_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_expressionprop OWNER TO www;

--
-- Name: TABLE feature_expressionprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_expressionprop IS 'Extensible properties for
feature_expression (comments, for example). Modeled on feature_cvtermprop.';


--
-- Name: feature_expressionprop_feature_expressionprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_expressionprop_feature_expressionprop_id_seq OWNER TO www;

--
-- Name: feature_expressionprop_feature_expressionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq OWNED BY chado.feature_expressionprop.feature_expressionprop_id;


--
-- Name: feature_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_feature_id_seq OWNER TO www;

--
-- Name: feature_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_feature_id_seq OWNED BY chado.feature.feature_id;


--
-- Name: feature_genotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_genotype (
    feature_genotype_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    genotype_id bigint NOT NULL,
    chromosome_id bigint,
    rank integer NOT NULL,
    cgroup integer NOT NULL,
    cvterm_id bigint NOT NULL
);


ALTER TABLE chado.feature_genotype OWNER TO www;

--
-- Name: COLUMN feature_genotype.chromosome_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_genotype.chromosome_id IS 'A feature of SO type "chromosome".';


--
-- Name: COLUMN feature_genotype.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_genotype.rank IS 'rank can be used for
n-ploid organisms or to preserve order.';


--
-- Name: COLUMN feature_genotype.cgroup; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_genotype.cgroup IS 'Spatially distinguishable
group. group can be used for distinguishing the chromosomal groups,
for example (RNAi products and so on can be treated as different
groups, as they do not fall on a particular chromosome).';


--
-- Name: feature_genotype_feature_genotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_genotype_feature_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_genotype_feature_genotype_id_seq OWNER TO www;

--
-- Name: feature_genotype_feature_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_genotype_feature_genotype_id_seq OWNED BY chado.feature_genotype.feature_genotype_id;


--
-- Name: feature_intersection; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_intersection AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id,
    x.srcfeature_id,
    x.strand AS subject_strand,
    y.strand AS object_strand,
        CASE
            WHEN (x.fmin < y.fmin) THEN y.fmin
            ELSE x.fmin
        END AS fmin,
        CASE
            WHEN (x.fmax > y.fmax) THEN y.fmax
            ELSE x.fmax
        END AS fmax
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax >= y.fmin) AND (x.fmin <= y.fmax)));


ALTER TABLE chado.feature_intersection OWNER TO www;

--
-- Name: VIEW feature_intersection; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_intersection IS 'set-intersection on interval defined by featureloc. featurelocs must meet';


--
-- Name: feature_meets; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_meets AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax >= y.fmin) AND (x.fmin <= y.fmax)));


ALTER TABLE chado.feature_meets OWNER TO www;

--
-- Name: VIEW feature_meets; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_meets IS 'intervals have at least one
interbase point in common (ie overlap OR abut). symmetric,reflexive';


--
-- Name: feature_meets_on_same_strand; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_meets_on_same_strand AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND (x.strand = y.strand) AND ((x.fmax >= y.fmin) AND (x.fmin <= y.fmax)));


ALTER TABLE chado.feature_meets_on_same_strand OWNER TO www;

--
-- Name: VIEW feature_meets_on_same_strand; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_meets_on_same_strand IS 'as feature_meets, but
featurelocs must be on the same strand. symmetric,reflexive';


--
-- Name: feature_phenotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_phenotype (
    feature_phenotype_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    phenotype_id bigint NOT NULL
);


ALTER TABLE chado.feature_phenotype OWNER TO www;

--
-- Name: TABLE feature_phenotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_phenotype IS 'Linking table between features and phenotypes.';


--
-- Name: feature_phenotype_feature_phenotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_phenotype_feature_phenotype_id_seq OWNER TO www;

--
-- Name: feature_phenotype_feature_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq OWNED BY chado.feature_phenotype.feature_phenotype_id;


--
-- Name: feature_project; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_project (
    feature_project_id integer NOT NULL,
    feature_id integer NOT NULL,
    project_id integer NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_project OWNER TO www;

--
-- Name: feature_project_feature_project_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_project_feature_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_project_feature_project_id_seq OWNER TO www;

--
-- Name: feature_project_feature_project_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_project_feature_project_id_seq OWNED BY chado.feature_project.feature_project_id;


--
-- Name: feature_pub_feature_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_pub_feature_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_pub_feature_pub_id_seq OWNER TO www;

--
-- Name: feature_pub_feature_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_pub_feature_pub_id_seq OWNED BY chado.feature_pub.feature_pub_id;


--
-- Name: feature_pubprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_pubprop (
    feature_pubprop_id bigint NOT NULL,
    feature_pub_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_pubprop OWNER TO www;

--
-- Name: TABLE feature_pubprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_pubprop IS 'Property or attribute of a feature_pub link.';


--
-- Name: feature_pubprop_feature_pubprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_pubprop_feature_pubprop_id_seq OWNER TO www;

--
-- Name: feature_pubprop_feature_pubprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq OWNED BY chado.feature_pubprop.feature_pubprop_id;


--
-- Name: feature_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_relationship (
    feature_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_relationship OWNER TO www;

--
-- Name: TABLE feature_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_relationship IS 'Features can be arranged in
graphs, e.g. "exon part_of transcript part_of gene"; If type is
thought of as a verb, the each arc or edge makes a statement
[Subject Verb Object]. The object can also be thought of as parent
(containing feature), and subject as child (contained feature or
subfeature). We include the relationship rank/order, because even
though most of the time we can order things implicitly by sequence
coordinates, we can not always do this - e.g. transpliced genes. It is also
useful for quickly getting implicit introns.';


--
-- Name: COLUMN feature_relationship.subject_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationship.subject_id IS 'The subject of the subj-predicate-obj sentence. This is typically the subfeature.';


--
-- Name: COLUMN feature_relationship.object_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationship.object_id IS 'The object of the subj-predicate-obj sentence. This is typically the container feature.';


--
-- Name: COLUMN feature_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationship.type_id IS 'Relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed. The most common relationship type is OBO_REL:part_of. Valid relationship types are constrained by the Sequence Ontology.';


--
-- Name: COLUMN feature_relationship.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationship.value IS 'Additional notes or comments.';


--
-- Name: COLUMN feature_relationship.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationship.rank IS 'The ordering of subject features with respect to the object feature may be important (for example, exon ordering on a transcript - not always derivable if you take trans spliced genes into consideration). Rank is used to order these; starts from zero.';


--
-- Name: feature_relationship_feature_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_relationship_feature_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_relationship_feature_relationship_id_seq OWNER TO www;

--
-- Name: feature_relationship_feature_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_relationship_feature_relationship_id_seq OWNED BY chado.feature_relationship.feature_relationship_id;


--
-- Name: feature_relationship_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_relationship_pub (
    feature_relationship_pub_id bigint NOT NULL,
    feature_relationship_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.feature_relationship_pub OWNER TO www;

--
-- Name: TABLE feature_relationship_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_relationship_pub IS 'Provenance. Attach optional evidence to a feature_relationship in the form of a chado.tion.';


--
-- Name: feature_relationship_pub_feature_relationship_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_relationship_pub_feature_relationship_pub_id_seq OWNER TO www;

--
-- Name: feature_relationship_pub_feature_relationship_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq OWNED BY chado.feature_relationship_pub.feature_relationship_pub_id;


--
-- Name: feature_relationshipprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_relationshipprop (
    feature_relationshipprop_id bigint NOT NULL,
    feature_relationship_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_relationshipprop OWNER TO www;

--
-- Name: TABLE feature_relationshipprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_relationshipprop IS 'Extensible properties
for feature_relationships. Analagous structure to featureprop. This
table is largely optional and not used with a high frequency. Typical
scenarios may be if one wishes to attach additional data to a
feature_relationship - for example to say that the
feature_relationship is only true in certain contexts.';


--
-- Name: COLUMN feature_relationshipprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationshipprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Currently there is no standard ontology for
feature_relationship property types.';


--
-- Name: COLUMN feature_relationshipprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationshipprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN feature_relationshipprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.feature_relationshipprop.rank IS 'Property-Value
ordering. Any feature_relationship can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: feature_relationshipprop_feature_relationshipprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_relationshipprop_feature_relationshipprop_id_seq OWNER TO www;

--
-- Name: feature_relationshipprop_feature_relationshipprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq OWNED BY chado.feature_relationshipprop.feature_relationshipprop_id;


--
-- Name: feature_relationshipprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_relationshipprop_pub (
    feature_relationshipprop_pub_id bigint NOT NULL,
    feature_relationshipprop_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.feature_relationshipprop_pub OWNER TO www;

--
-- Name: TABLE feature_relationshipprop_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.feature_relationshipprop_pub IS 'Provenance for feature_relationshipprop.';


--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq OWNER TO www;

--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq OWNED BY chado.feature_relationshipprop_pub.feature_relationshipprop_pub_id;


--
-- Name: feature_stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.feature_stock (
    feature_stock_id integer NOT NULL,
    feature_id integer NOT NULL,
    stock_id integer NOT NULL,
    type_id integer NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.feature_stock OWNER TO www;

--
-- Name: feature_stock_feature_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_stock_feature_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_stock_feature_stock_id_seq OWNER TO www;

--
-- Name: feature_stock_feature_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_stock_feature_stock_id_seq OWNED BY chado.feature_stock.feature_stock_id;


--
-- Name: feature_synonym_feature_synonym_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_synonym_feature_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_synonym_feature_synonym_id_seq OWNER TO www;

--
-- Name: feature_synonym_feature_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.feature_synonym_feature_synonym_id_seq OWNED BY chado.feature_synonym.feature_synonym_id;


--
-- Name: feature_union; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.feature_union AS
 SELECT x.feature_id AS subject_id,
    y.feature_id AS object_id,
    x.srcfeature_id,
    x.strand AS subject_strand,
    y.strand AS object_strand,
        CASE
            WHEN (x.fmin < y.fmin) THEN x.fmin
            ELSE y.fmin
        END AS fmin,
        CASE
            WHEN (x.fmax > y.fmax) THEN x.fmax
            ELSE y.fmax
        END AS fmax
   FROM chado.featureloc x,
    chado.featureloc y
  WHERE ((x.srcfeature_id = y.srcfeature_id) AND ((x.fmax >= y.fmin) AND (x.fmin <= y.fmax)));


ALTER TABLE chado.feature_union OWNER TO www;

--
-- Name: VIEW feature_union; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.feature_union IS 'set-union on interval defined by featureloc. featurelocs must meet';


--
-- Name: feature_uniquename_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.feature_uniquename_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.feature_uniquename_seq OWNER TO www;

--
-- Name: featureloc_featureloc_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featureloc_featureloc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featureloc_featureloc_id_seq OWNER TO www;

--
-- Name: featureloc_featureloc_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featureloc_featureloc_id_seq OWNED BY chado.featureloc.featureloc_id;


--
-- Name: featureloc_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featureloc_pub (
    featureloc_pub_id bigint NOT NULL,
    featureloc_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.featureloc_pub OWNER TO www;

--
-- Name: TABLE featureloc_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featureloc_pub IS 'Provenance of featureloc. Linking table between featurelocs and chado.tions that mention them.';


--
-- Name: featureloc_pub_featureloc_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featureloc_pub_featureloc_pub_id_seq OWNER TO www;

--
-- Name: featureloc_pub_featureloc_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq OWNED BY chado.featureloc_pub.featureloc_pub_id;


--
-- Name: featurelocprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featurelocprop (
    featurelocprop_id integer NOT NULL,
    featureloc_id integer NOT NULL,
    type_id integer NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.featurelocprop OWNER TO www;

--
-- Name: featurelocprop_featurelocprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featurelocprop_featurelocprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featurelocprop_featurelocprop_id_seq OWNER TO www;

--
-- Name: featurelocprop_featurelocprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featurelocprop_featurelocprop_id_seq OWNED BY chado.featurelocprop.featurelocprop_id;


--
-- Name: featuremap; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap (
    featuremap_id bigint NOT NULL,
    name character varying(255),
    description text,
    unittype_id bigint
);


ALTER TABLE chado.featuremap OWNER TO www;

--
-- Name: featuremap_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap_contact (
    featuremap_contact_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    contact_id bigint NOT NULL
);


ALTER TABLE chado.featuremap_contact OWNER TO www;

--
-- Name: TABLE featuremap_contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featuremap_contact IS 'Links contact(s) with a featuremap.  Used to 
indicate a particular person or organization responsible for constrution of or 
that can provide more information on a particular featuremap.';


--
-- Name: featuremap_contact_featuremap_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_contact_featuremap_contact_id_seq OWNER TO www;

--
-- Name: featuremap_contact_featuremap_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq OWNED BY chado.featuremap_contact.featuremap_contact_id;


--
-- Name: featuremap_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap_dbxref (
    featuremap_dbxref_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.featuremap_dbxref OWNER TO www;

--
-- Name: featuremap_dbxref_featuremap_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_dbxref_featuremap_dbxref_id_seq OWNER TO www;

--
-- Name: featuremap_dbxref_featuremap_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq OWNED BY chado.featuremap_dbxref.featuremap_dbxref_id;


--
-- Name: featuremap_featuremap_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_featuremap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_featuremap_id_seq OWNER TO www;

--
-- Name: featuremap_featuremap_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_featuremap_id_seq OWNED BY chado.featuremap.featuremap_id;


--
-- Name: featuremap_organism; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap_organism (
    featuremap_organism_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    organism_id bigint NOT NULL
);


ALTER TABLE chado.featuremap_organism OWNER TO www;

--
-- Name: TABLE featuremap_organism; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featuremap_organism IS 'Links a featuremap to the organism(s) with which it is associated.';


--
-- Name: featuremap_organism_featuremap_organism_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_organism_featuremap_organism_id_seq OWNER TO www;

--
-- Name: featuremap_organism_featuremap_organism_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq OWNED BY chado.featuremap_organism.featuremap_organism_id;


--
-- Name: featuremap_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap_pub (
    featuremap_pub_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.featuremap_pub OWNER TO www;

--
-- Name: featuremap_pub_featuremap_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_pub_featuremap_pub_id_seq OWNER TO www;

--
-- Name: featuremap_pub_featuremap_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq OWNED BY chado.featuremap_pub.featuremap_pub_id;


--
-- Name: featuremap_stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremap_stock (
    featuremap_stock_id integer NOT NULL,
    featuremap_id integer NOT NULL,
    stock_id integer NOT NULL
);


ALTER TABLE chado.featuremap_stock OWNER TO www;

--
-- Name: featuremap_stock_featuremap_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremap_stock_featuremap_stock_id_seq OWNER TO www;

--
-- Name: featuremap_stock_featuremap_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq OWNED BY chado.featuremap_stock.featuremap_stock_id;


--
-- Name: featuremapprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featuremapprop (
    featuremapprop_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.featuremapprop OWNER TO www;

--
-- Name: TABLE featuremapprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featuremapprop IS 'A featuremap can have any number of slot-value property 
tags attached to it. This is an alternative to hardcoding a list of columns in the 
relational schema, and is completely extensible.';


--
-- Name: featuremapprop_featuremapprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featuremapprop_featuremapprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featuremapprop_featuremapprop_id_seq OWNER TO www;

--
-- Name: featuremapprop_featuremapprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featuremapprop_featuremapprop_id_seq OWNED BY chado.featuremapprop.featuremapprop_id;


--
-- Name: featurepos; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featurepos (
    featurepos_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    map_feature_id bigint NOT NULL,
    mappos double precision NOT NULL
);


ALTER TABLE chado.featurepos OWNER TO www;

--
-- Name: COLUMN featurepos.map_feature_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featurepos.map_feature_id IS 'map_feature_id
links to the feature (map) upon which the feature is being localized.';


--
-- Name: featurepos_featurepos_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featurepos_featurepos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featurepos_featurepos_id_seq OWNER TO www;

--
-- Name: featurepos_featurepos_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featurepos_featurepos_id_seq OWNED BY chado.featurepos.featurepos_id;


--
-- Name: featureposprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featureposprop (
    featureposprop_id bigint NOT NULL,
    featurepos_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.featureposprop OWNER TO www;

--
-- Name: TABLE featureposprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featureposprop IS 'Property or attribute of a featurepos record.';


--
-- Name: featureposprop_featureposprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featureposprop_featureposprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featureposprop_featureposprop_id_seq OWNER TO www;

--
-- Name: featureposprop_featureposprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featureposprop_featureposprop_id_seq OWNED BY chado.featureposprop.featureposprop_id;


--
-- Name: featureprop_featureprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featureprop_featureprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featureprop_featureprop_id_seq OWNER TO www;

--
-- Name: featureprop_featureprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featureprop_featureprop_id_seq OWNED BY chado.featureprop.featureprop_id;


--
-- Name: featureprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featureprop_pub (
    featureprop_pub_id bigint NOT NULL,
    featureprop_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.featureprop_pub OWNER TO www;

--
-- Name: TABLE featureprop_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featureprop_pub IS 'Provenance. Any featureprop assignment can optionally be supported by a chado.tion.';


--
-- Name: featureprop_pub_featureprop_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featureprop_pub_featureprop_pub_id_seq OWNER TO www;

--
-- Name: featureprop_pub_featureprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq OWNED BY chado.featureprop_pub.featureprop_pub_id;


--
-- Name: featurerange; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.featurerange (
    featurerange_id bigint NOT NULL,
    featuremap_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    leftstartf_id bigint NOT NULL,
    leftendf_id bigint,
    rightstartf_id bigint,
    rightendf_id bigint NOT NULL,
    rangestr character varying(255)
);


ALTER TABLE chado.featurerange OWNER TO www;

--
-- Name: TABLE featurerange; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.featurerange IS 'In cases where the start and end of a mapped feature is a range, leftendf and rightstartf are populated. leftstartf_id, leftendf_id, rightstartf_id, rightendf_id are the ids of features with respect to which the feature is being mapped. These may be cytological bands.';


--
-- Name: COLUMN featurerange.featuremap_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.featurerange.featuremap_id IS 'featuremap_id is the id of the feature being mapped.';


--
-- Name: featurerange_featurerange_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.featurerange_featurerange_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.featurerange_featurerange_id_seq OWNER TO www;

--
-- Name: featurerange_featurerange_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.featurerange_featurerange_id_seq OWNED BY chado.featurerange.featurerange_id;


--
-- Name: featureset_meets; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.featureset_meets AS
 SELECT x.object_id AS subject_id,
    y.object_id
   FROM ((chado.feature_meets r
     JOIN chado.feature_relationship x ON ((r.subject_id = x.subject_id)))
     JOIN chado.feature_relationship y ON ((r.object_id = y.subject_id)));


ALTER TABLE chado.featureset_meets OWNER TO www;

--
-- Name: fnr_type; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.fnr_type AS
 SELECT f.feature_id,
    f.name,
    f.dbxref_id,
    c.name AS type,
    f.residues,
    f.seqlen,
    f.md5checksum,
    f.type_id,
    f.timeaccessioned,
    f.timelastmodified
   FROM (chado.feature f
     LEFT JOIN chado.analysisfeature af ON ((f.feature_id = af.feature_id))),
    chado.cvterm c
  WHERE ((f.type_id = c.cvterm_id) AND (af.feature_id IS NULL));


ALTER TABLE chado.fnr_type OWNER TO www;

--
-- Name: fp_key; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.fp_key AS
 SELECT fp.feature_id,
    c.name AS pkey,
    fp.value
   FROM chado.featureprop fp,
    chado.cvterm c
  WHERE (fp.featureprop_id = c.cvterm_id);


ALTER TABLE chado.fp_key OWNER TO www;

--
-- Name: gene; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.gene (
    nid bigint NOT NULL,
    gene_id bigint NOT NULL,
    organism_id bigint,
    srcfeature_id bigint,
    abbreviation text,
    genus text,
    species text,
    name text,
    uniquename text,
    stop bigint NOT NULL,
    start bigint NOT NULL,
    strand bigint NOT NULL,
    coordinate text,
    gene_family text,
    description text,
    domains text
);


ALTER TABLE chado.gene OWNER TO www;

--
-- Name: gene2domain; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.gene2domain (
    domains text,
    gene_id integer NOT NULL
);


ALTER TABLE chado.gene2domain OWNER TO www;

--
-- Name: genome_metadata; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.genome_metadata (
    project_nid integer NOT NULL,
    project_id integer NOT NULL,
    project character varying(255) NOT NULL,
    project_description text NOT NULL,
    funding text NOT NULL,
    consortium text NOT NULL,
    consortium_url text NOT NULL,
    bioproject text NOT NULL,
    bioproject_db integer NOT NULL,
    stock_nid integer NOT NULL,
    stock_id integer NOT NULL,
    stock_name character varying(255),
    sample_description text,
    biosample text NOT NULL,
    biosample_db integer NOT NULL,
    analysis_nid integer,
    analysis_id integer,
    assembly_name character varying(255),
    program character varying(255) NOT NULL,
    nd_experiment_id integer NOT NULL,
    doi character varying(255) NOT NULL,
    pmid character varying(255) NOT NULL
);


ALTER TABLE chado.genome_metadata OWNER TO www;

--
-- Name: genotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.genotype (
    genotype_id bigint NOT NULL,
    name text,
    uniquename text NOT NULL,
    description text,
    type_id bigint NOT NULL
);


ALTER TABLE chado.genotype OWNER TO www;

--
-- Name: TABLE genotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.genotype IS 'Genetic context. A genotype is defined by a collection of features, mutations, balancers, deficiencies, haplotype blocks, or engineered constructs.';


--
-- Name: COLUMN genotype.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.genotype.name IS 'Optional alternative name for a genotype, 
for display purposes.';


--
-- Name: COLUMN genotype.uniquename; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.genotype.uniquename IS 'The unique name for a genotype; 
typically derived from the features making up the genotype.';


--
-- Name: genotype_genotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.genotype_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.genotype_genotype_id_seq OWNER TO www;

--
-- Name: genotype_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.genotype_genotype_id_seq OWNED BY chado.genotype.genotype_id;


--
-- Name: genotypeprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.genotypeprop (
    genotypeprop_id bigint NOT NULL,
    genotype_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.genotypeprop OWNER TO www;

--
-- Name: genotypeprop_genotypeprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.genotypeprop_genotypeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.genotypeprop_genotypeprop_id_seq OWNER TO www;

--
-- Name: genotypeprop_genotypeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.genotypeprop_genotypeprop_id_seq OWNED BY chado.genotypeprop.genotypeprop_id;


--
-- Name: gff3atts; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.gff3atts AS
 SELECT fs.feature_id,
    'Ontology_term'::text AS type,
        CASE
            WHEN ((db.name)::text ~~ '%Gene Ontology%'::text) THEN (('GO:'::text || (dbx.accession)::text))::character varying
            WHEN ((db.name)::text ~~ 'Sequence Ontology%'::text) THEN (('SO:'::text || (dbx.accession)::text))::character varying
            ELSE ((((db.name)::text || ':'::text) || (dbx.accession)::text))::character varying
        END AS attribute
   FROM chado.cvterm s,
    chado.dbxref dbx,
    chado.feature_cvterm fs,
    chado.db
  WHERE ((fs.cvterm_id = s.cvterm_id) AND (s.dbxref_id = dbx.dbxref_id) AND (db.db_id = dbx.db_id))
UNION ALL
 SELECT fs.feature_id,
    'Dbxref'::text AS type,
    (((d.name)::text || ':'::text) || (s.accession)::text) AS attribute
   FROM chado.dbxref s,
    chado.feature_dbxref fs,
    chado.db d
  WHERE ((fs.dbxref_id = s.dbxref_id) AND (s.db_id = d.db_id) AND ((d.name)::text <> 'GFF_source'::text))
UNION ALL
 SELECT f.feature_id,
    'Alias'::text AS type,
    s.name AS attribute
   FROM chado.synonym s,
    chado.feature_synonym fs,
    chado.feature f
  WHERE ((fs.synonym_id = s.synonym_id) AND (f.feature_id = fs.feature_id) AND ((f.name)::text <> (s.name)::text) AND (f.uniquename <> (s.name)::text))
UNION ALL
 SELECT fp.feature_id,
    cv.name AS type,
    fp.value AS attribute
   FROM chado.featureprop fp,
    chado.cvterm cv
  WHERE (fp.type_id = cv.cvterm_id)
UNION ALL
 SELECT fs.feature_id,
    'pub'::text AS type,
    (((s.series_name)::text || ':'::text) || s.title) AS attribute
   FROM chado.pub s,
    chado.feature_pub fs
  WHERE (fs.pub_id = s.pub_id)
UNION ALL
 SELECT fr.subject_id AS feature_id,
    'Parent'::text AS type,
    parent.uniquename AS attribute
   FROM chado.feature_relationship fr,
    chado.feature parent
  WHERE ((fr.object_id = parent.feature_id) AND (fr.type_id = ( SELECT cvterm.cvterm_id
           FROM chado.cvterm
          WHERE (((cvterm.name)::text = 'part_of'::text) AND (cvterm.cv_id IN ( SELECT cv.cv_id
                   FROM chado.cv
                  WHERE ((cv.name)::text = 'relationship'::text)))))))
UNION ALL
 SELECT fr.subject_id AS feature_id,
    'Derives_from'::text AS type,
    parent.uniquename AS attribute
   FROM chado.feature_relationship fr,
    chado.feature parent
  WHERE ((fr.object_id = parent.feature_id) AND (fr.type_id = ( SELECT cvterm.cvterm_id
           FROM chado.cvterm
          WHERE (((cvterm.name)::text = 'derives_from'::text) AND (cvterm.cv_id IN ( SELECT cv.cv_id
                   FROM chado.cv
                  WHERE ((cv.name)::text = 'relationship'::text)))))))
UNION ALL
 SELECT fl.feature_id,
    'Target'::text AS type,
    (((((((target.name)::text || ' '::text) || (fl.fmin + 1)) || ' '::text) || fl.fmax) || ' '::text) || fl.strand) AS attribute
   FROM chado.featureloc fl,
    chado.feature target
  WHERE ((fl.srcfeature_id = target.feature_id) AND (fl.rank <> 0))
UNION ALL
 SELECT feature.feature_id,
    'ID'::text AS type,
    feature.uniquename AS attribute
   FROM chado.feature
  WHERE (NOT (feature.type_id IN ( SELECT cvterm.cvterm_id
           FROM chado.cvterm
          WHERE ((cvterm.name)::text = 'CDS'::text))))
UNION ALL
 SELECT feature.feature_id,
    'chado_feature_id'::text AS type,
    (feature.feature_id)::character varying AS attribute
   FROM chado.feature
UNION ALL
 SELECT feature.feature_id,
    'Name'::text AS type,
    feature.name AS attribute
   FROM chado.feature;


ALTER TABLE chado.gff3atts OWNER TO www;

--
-- Name: gff3view; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.gff3view AS
 SELECT f.feature_id,
    sf.name AS ref,
    COALESCE(gffdbx.accession, '.'::character varying(255)) AS source,
    cv.name AS type,
    (fl.fmin + 1) AS fstart,
    fl.fmax AS fend,
    COALESCE((af.significance)::text, '.'::text) AS score,
        CASE
            WHEN (fl.strand = '-1'::integer) THEN '-'::text
            WHEN (fl.strand = 1) THEN '+'::text
            ELSE '.'::text
        END AS strand,
    COALESCE((fl.phase)::text, '.'::text) AS phase,
    f.seqlen,
    f.name,
    f.organism_id
   FROM (((((chado.feature f
     LEFT JOIN chado.featureloc fl ON ((f.feature_id = fl.feature_id)))
     LEFT JOIN chado.feature sf ON ((fl.srcfeature_id = sf.feature_id)))
     LEFT JOIN ( SELECT fd.feature_id,
            d.accession
           FROM ((chado.feature_dbxref fd
             JOIN chado.dbxref d USING (dbxref_id))
             JOIN chado.db USING (db_id))
          WHERE ((db.name)::text = 'GFF_source'::text)) gffdbx ON ((f.feature_id = gffdbx.feature_id)))
     LEFT JOIN chado.cvterm cv ON ((f.type_id = cv.cvterm_id)))
     LEFT JOIN chado.analysisfeature af ON ((f.feature_id = af.feature_id)));


ALTER TABLE chado.gff3view OWNER TO www;

--
-- Name: gff_meta; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.gff_meta (
    name character varying(100),
    hostname character varying(100),
    starttime timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE chado.gff_meta OWNER TO www;

--
-- Name: intron_combined_view; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.intron_combined_view AS
 SELECT x1.feature_id AS exon1_id,
    x2.feature_id AS exon2_id,
        CASE
            WHEN (l1.strand = '-1'::integer) THEN l2.fmax
            ELSE l1.fmax
        END AS fmin,
        CASE
            WHEN (l1.strand = '-1'::integer) THEN l1.fmin
            ELSE l2.fmin
        END AS fmax,
    l1.strand,
    l1.srcfeature_id,
    r1.rank AS intron_rank,
    r1.object_id AS transcript_id
   FROM ((((((chado.cvterm
     JOIN chado.feature x1 ON ((x1.type_id = cvterm.cvterm_id)))
     JOIN chado.feature_relationship r1 ON ((x1.feature_id = r1.subject_id)))
     JOIN chado.featureloc l1 ON ((x1.feature_id = l1.feature_id)))
     JOIN chado.feature x2 ON ((x2.type_id = cvterm.cvterm_id)))
     JOIN chado.feature_relationship r2 ON ((x2.feature_id = r2.subject_id)))
     JOIN chado.featureloc l2 ON ((x2.feature_id = l2.feature_id)))
  WHERE (((cvterm.name)::text = 'exon'::text) AND ((r2.rank - r1.rank) = 1) AND (r1.object_id = r2.object_id) AND (l1.strand = l2.strand) AND (l1.srcfeature_id = l2.srcfeature_id) AND (l1.locgroup = 0) AND (l2.locgroup = 0));


ALTER TABLE chado.intron_combined_view OWNER TO www;

--
-- Name: intronloc_view; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.intronloc_view AS
 SELECT DISTINCT intron_combined_view.exon1_id,
    intron_combined_view.exon2_id,
    intron_combined_view.fmin,
    intron_combined_view.fmax,
    intron_combined_view.strand,
    intron_combined_view.srcfeature_id
   FROM chado.intron_combined_view;


ALTER TABLE chado.intronloc_view OWNER TO www;

--
-- Name: library; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library (
    library_id bigint NOT NULL,
    organism_id bigint NOT NULL,
    name character varying(255),
    uniquename text NOT NULL,
    type_id bigint NOT NULL,
    is_obsolete integer DEFAULT 0 NOT NULL,
    timeaccessioned timestamp without time zone DEFAULT now() NOT NULL,
    timelastmodified timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE chado.library OWNER TO www;

--
-- Name: COLUMN library.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.library.type_id IS 'The type_id foreign key links to a controlled vocabulary of library types. Examples of this would be: "cDNA_library" or "genomic_library"';


--
-- Name: library_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_contact (
    library_contact_id bigint NOT NULL,
    library_id bigint NOT NULL,
    contact_id bigint NOT NULL
);


ALTER TABLE chado.library_contact OWNER TO www;

--
-- Name: TABLE library_contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_contact IS 'Links contact(s) with a library.  Used to indicate a particular person or organization responsible for creation of or that can provide more information on a particular library.';


--
-- Name: library_contact_library_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_contact_library_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_contact_library_contact_id_seq OWNER TO www;

--
-- Name: library_contact_library_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_contact_library_contact_id_seq OWNED BY chado.library_contact.library_contact_id;


--
-- Name: library_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_cvterm (
    library_cvterm_id bigint NOT NULL,
    library_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.library_cvterm OWNER TO www;

--
-- Name: TABLE library_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_cvterm IS 'The table library_cvterm links a library to controlled vocabularies which describe the library.  For instance, there might be a link to the anatomy cv for "head" or "testes" for a head or testes library.';


--
-- Name: library_cvterm_library_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_cvterm_library_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_cvterm_library_cvterm_id_seq OWNER TO www;

--
-- Name: library_cvterm_library_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_cvterm_library_cvterm_id_seq OWNED BY chado.library_cvterm.library_cvterm_id;


--
-- Name: library_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_dbxref (
    library_dbxref_id bigint NOT NULL,
    library_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.library_dbxref OWNER TO www;

--
-- Name: TABLE library_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_dbxref IS 'Links a library to dbxrefs.';


--
-- Name: library_dbxref_library_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_dbxref_library_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_dbxref_library_dbxref_id_seq OWNER TO www;

--
-- Name: library_dbxref_library_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_dbxref_library_dbxref_id_seq OWNED BY chado.library_dbxref.library_dbxref_id;


--
-- Name: library_expression; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_expression (
    library_expression_id bigint NOT NULL,
    library_id bigint NOT NULL,
    expression_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.library_expression OWNER TO www;

--
-- Name: TABLE library_expression; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_expression IS 'Links a library to expression statements.';


--
-- Name: library_expression_library_expression_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_expression_library_expression_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_expression_library_expression_id_seq OWNER TO www;

--
-- Name: library_expression_library_expression_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_expression_library_expression_id_seq OWNED BY chado.library_expression.library_expression_id;


--
-- Name: library_expressionprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_expressionprop (
    library_expressionprop_id bigint NOT NULL,
    library_expression_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.library_expressionprop OWNER TO www;

--
-- Name: TABLE library_expressionprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_expressionprop IS 'Attributes of a library_expression relationship.';


--
-- Name: library_expressionprop_library_expressionprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_expressionprop_library_expressionprop_id_seq OWNER TO www;

--
-- Name: library_expressionprop_library_expressionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq OWNED BY chado.library_expressionprop.library_expressionprop_id;


--
-- Name: library_feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_feature (
    library_feature_id bigint NOT NULL,
    library_id bigint NOT NULL,
    feature_id bigint NOT NULL
);


ALTER TABLE chado.library_feature OWNER TO www;

--
-- Name: TABLE library_feature; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_feature IS 'library_feature links a library to the clones which are contained in the library.  Examples of such linked features might be "cDNA_clone" or  "genomic_clone".';


--
-- Name: library_feature_count; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_feature_count (
    library_id integer,
    name character varying(255),
    num_features integer,
    feature_type character varying(255)
);


ALTER TABLE chado.library_feature_count OWNER TO www;

--
-- Name: library_feature_library_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_feature_library_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_feature_library_feature_id_seq OWNER TO www;

--
-- Name: library_feature_library_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_feature_library_feature_id_seq OWNED BY chado.library_feature.library_feature_id;


--
-- Name: library_featureprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_featureprop (
    library_featureprop_id bigint NOT NULL,
    library_feature_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.library_featureprop OWNER TO www;

--
-- Name: TABLE library_featureprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_featureprop IS 'Attributes of a library_feature relationship.';


--
-- Name: library_featureprop_library_featureprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_featureprop_library_featureprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_featureprop_library_featureprop_id_seq OWNER TO www;

--
-- Name: library_featureprop_library_featureprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_featureprop_library_featureprop_id_seq OWNED BY chado.library_featureprop.library_featureprop_id;


--
-- Name: library_library_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_library_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_library_id_seq OWNER TO www;

--
-- Name: library_library_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_library_id_seq OWNED BY chado.library.library_id;


--
-- Name: library_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_pub (
    library_pub_id bigint NOT NULL,
    library_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.library_pub OWNER TO www;

--
-- Name: TABLE library_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_pub IS 'Attribution for a library.';


--
-- Name: library_pub_library_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_pub_library_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_pub_library_pub_id_seq OWNER TO www;

--
-- Name: library_pub_library_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_pub_library_pub_id_seq OWNED BY chado.library_pub.library_pub_id;


--
-- Name: library_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_relationship (
    library_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.library_relationship OWNER TO www;

--
-- Name: TABLE library_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_relationship IS 'Relationships between libraries.';


--
-- Name: library_relationship_library_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_relationship_library_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_relationship_library_relationship_id_seq OWNER TO www;

--
-- Name: library_relationship_library_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_relationship_library_relationship_id_seq OWNED BY chado.library_relationship.library_relationship_id;


--
-- Name: library_relationship_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_relationship_pub (
    library_relationship_pub_id bigint NOT NULL,
    library_relationship_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.library_relationship_pub OWNER TO www;

--
-- Name: TABLE library_relationship_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_relationship_pub IS 'Provenance of library_relationship.';


--
-- Name: library_relationship_pub_library_relationship_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_relationship_pub_library_relationship_pub_id_seq OWNER TO www;

--
-- Name: library_relationship_pub_library_relationship_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq OWNED BY chado.library_relationship_pub.library_relationship_pub_id;


--
-- Name: library_synonym; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.library_synonym (
    library_synonym_id bigint NOT NULL,
    synonym_id bigint NOT NULL,
    library_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL,
    is_internal boolean DEFAULT false NOT NULL
);


ALTER TABLE chado.library_synonym OWNER TO www;

--
-- Name: TABLE library_synonym; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.library_synonym IS 'Linking table between library and synonym.';


--
-- Name: COLUMN library_synonym.pub_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.library_synonym.pub_id IS 'The pub_id link is for
relating the usage of a given synonym to the publication in which it was used.';


--
-- Name: COLUMN library_synonym.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.library_synonym.is_current IS 'The is_current bit indicates whether the linked synonym is the current -official- symbol for the linked library.';


--
-- Name: COLUMN library_synonym.is_internal; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.library_synonym.is_internal IS 'Typically a synonym
exists so that somebody querying the database with an obsolete name
can find the object they are looking for under its current name.  If
the synonym has been used publicly and deliberately (e.g. in a paper), it my also be listed in reports as a synonym.   If the synonym was not used deliberately (e.g., there was a typo which went public), then the is_internal bit may be set to "true" so that it is known that the synonym is "internal" and should be queryable but should not be listed in reports as a valid synonym.';


--
-- Name: library_synonym_library_synonym_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.library_synonym_library_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.library_synonym_library_synonym_id_seq OWNER TO www;

--
-- Name: library_synonym_library_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.library_synonym_library_synonym_id_seq OWNED BY chado.library_synonym.library_synonym_id;


--
-- Name: libraryprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.libraryprop (
    libraryprop_id bigint NOT NULL,
    library_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.libraryprop OWNER TO www;

--
-- Name: TABLE libraryprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.libraryprop IS 'Tag-value properties - follows standard chado model.';


--
-- Name: libraryprop_libraryprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.libraryprop_libraryprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.libraryprop_libraryprop_id_seq OWNER TO www;

--
-- Name: libraryprop_libraryprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.libraryprop_libraryprop_id_seq OWNED BY chado.libraryprop.libraryprop_id;


--
-- Name: libraryprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.libraryprop_pub (
    libraryprop_pub_id bigint NOT NULL,
    libraryprop_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.libraryprop_pub OWNER TO www;

--
-- Name: TABLE libraryprop_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.libraryprop_pub IS 'Attribution for libraryprop.';


--
-- Name: libraryprop_pub_libraryprop_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.libraryprop_pub_libraryprop_pub_id_seq OWNER TO www;

--
-- Name: libraryprop_pub_libraryprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq OWNED BY chado.libraryprop_pub.libraryprop_pub_id;


--
-- Name: lightshop_order; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.lightshop_order (
    oid integer NOT NULL,
    nid bigint DEFAULT 0 NOT NULL,
    mail character varying(254) DEFAULT ''::character varying,
    items bytea,
    code character varying(64) DEFAULT 0 NOT NULL,
    CONSTRAINT lightshop_order_nid_check CHECK ((nid >= 0))
);


ALTER TABLE chado.lightshop_order OWNER TO www;

--
-- Name: TABLE lightshop_order; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.lightshop_order IS 'Stores order information for Light Shop module.';


--
-- Name: COLUMN lightshop_order.oid; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.lightshop_order.oid IS 'Primary Key: Unique order ID.';


--
-- Name: COLUMN lightshop_order.nid; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.lightshop_order.nid IS 'The order''s node.nid.';


--
-- Name: COLUMN lightshop_order.mail; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.lightshop_order.mail IS 'User''s e-mail address.';


--
-- Name: COLUMN lightshop_order.items; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.lightshop_order.items IS 'Order items array';


--
-- Name: COLUMN lightshop_order.code; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.lightshop_order.code IS 'Order code to identify an anonymous user.';


--
-- Name: lightshop_order_oid_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.lightshop_order_oid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.lightshop_order_oid_seq OWNER TO www;

--
-- Name: lightshop_order_oid_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.lightshop_order_oid_seq OWNED BY chado.lightshop_order.oid;


--
-- Name: magedocumentation; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.magedocumentation (
    magedocumentation_id bigint NOT NULL,
    mageml_id bigint NOT NULL,
    tableinfo_id bigint NOT NULL,
    row_id integer NOT NULL,
    mageidentifier text NOT NULL
);


ALTER TABLE chado.magedocumentation OWNER TO www;

--
-- Name: magedocumentation_magedocumentation_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.magedocumentation_magedocumentation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.magedocumentation_magedocumentation_id_seq OWNER TO www;

--
-- Name: magedocumentation_magedocumentation_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.magedocumentation_magedocumentation_id_seq OWNED BY chado.magedocumentation.magedocumentation_id;


--
-- Name: mageml; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.mageml (
    mageml_id bigint NOT NULL,
    mage_package text NOT NULL,
    mage_ml text NOT NULL
);


ALTER TABLE chado.mageml OWNER TO www;

--
-- Name: TABLE mageml; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.mageml IS 'This table is for storing extra bits of MAGEml in a denormalized form. More normalization would require many more tables.';


--
-- Name: mageml_mageml_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.mageml_mageml_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.mageml_mageml_id_seq OWNER TO www;

--
-- Name: mageml_mageml_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.mageml_mageml_id_seq OWNED BY chado.mageml.mageml_id;


--
-- Name: marker_search; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.marker_search (
    organism text NOT NULL,
    organism_nid integer NOT NULL,
    cmarker character varying(255) NOT NULL,
    cmarker_id integer,
    cmarker_nid integer NOT NULL,
    markers text,
    marker_ids text,
    synonyms text,
    all_names text,
    pub_nid integer,
    citation text
);


ALTER TABLE chado.marker_search OWNER TO www;

--
-- Name: materialized_view; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.materialized_view (
    materialized_view_id integer NOT NULL,
    last_update timestamp without time zone,
    refresh_time integer,
    name character varying(64),
    mv_schema character varying(64),
    mv_table character varying(128),
    mv_specs text,
    indexed text,
    query text,
    special_index text
);


ALTER TABLE chado.materialized_view OWNER TO www;

--
-- Name: materialized_view_materialized_view_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.materialized_view_materialized_view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.materialized_view_materialized_view_id_seq OWNER TO www;

--
-- Name: materialized_view_materialized_view_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.materialized_view_materialized_view_id_seq OWNED BY chado.materialized_view.materialized_view_id;


--
-- Name: nd_experiment; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment (
    nd_experiment_id bigint NOT NULL,
    nd_geolocation_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment OWNER TO www;

--
-- Name: TABLE nd_experiment; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment IS 'This is the core table for the natural diversity module, 
representing each individual assay that is undertaken (this is usually *not* an 
entire experiment). Each nd_experiment should give rise to a single genotype or 
phenotype and be described via 1 (or more) protocols. Collections of assays that 
relate to each other should be linked to the same record in the project table.';


--
-- Name: nd_experiment_analysis; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_analysis (
    nd_experiment_analysis_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    analysis_id bigint NOT NULL,
    type_id bigint
);


ALTER TABLE chado.nd_experiment_analysis OWNER TO www;

--
-- Name: TABLE nd_experiment_analysis; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_analysis IS 'An analysis that is used in an experiment';


--
-- Name: nd_experiment_analysis_nd_experiment_analysis_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq OWNER TO www;

--
-- Name: nd_experiment_analysis_nd_experiment_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq OWNED BY chado.nd_experiment_analysis.nd_experiment_analysis_id;


--
-- Name: nd_experiment_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_contact (
    nd_experiment_contact_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    contact_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_contact OWNER TO www;

--
-- Name: nd_experiment_contact_nd_experiment_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_contact_nd_experiment_contact_id_seq OWNER TO www;

--
-- Name: nd_experiment_contact_nd_experiment_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq OWNED BY chado.nd_experiment_contact.nd_experiment_contact_id;


--
-- Name: nd_experiment_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_dbxref (
    nd_experiment_dbxref_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_dbxref OWNER TO www;

--
-- Name: TABLE nd_experiment_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_dbxref IS 'Cross-reference experiment to accessions, images, etc';


--
-- Name: nd_experiment_dbxref_nd_experiment_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq OWNER TO www;

--
-- Name: nd_experiment_dbxref_nd_experiment_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq OWNED BY chado.nd_experiment_dbxref.nd_experiment_dbxref_id;


--
-- Name: nd_experiment_genotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_genotype (
    nd_experiment_genotype_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    genotype_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_genotype OWNER TO www;

--
-- Name: TABLE nd_experiment_genotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_genotype IS 'Linking table: experiments to the genotypes they produce. There is a one-to-one relationship between an experiment and a genotype since each genotype record should point to one experiment. Add a new experiment_id for each genotype record.';


--
-- Name: nd_experiment_genotype_nd_experiment_genotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq OWNER TO www;

--
-- Name: nd_experiment_genotype_nd_experiment_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq OWNED BY chado.nd_experiment_genotype.nd_experiment_genotype_id;


--
-- Name: nd_experiment_nd_experiment_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_nd_experiment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_nd_experiment_id_seq OWNER TO www;

--
-- Name: nd_experiment_nd_experiment_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_nd_experiment_id_seq OWNED BY chado.nd_experiment.nd_experiment_id;


--
-- Name: nd_experiment_phenotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_phenotype (
    nd_experiment_phenotype_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    phenotype_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_phenotype OWNER TO www;

--
-- Name: TABLE nd_experiment_phenotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_phenotype IS 'Linking table: experiments to the phenotypes they produce. There is a one-to-one relationship between an experiment and a phenotype since each phenotype record should point to one experiment. Add a new experiment_id for each phenotype record.';


--
-- Name: nd_experiment_phenotype_nd_experiment_phenotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq OWNER TO www;

--
-- Name: nd_experiment_phenotype_nd_experiment_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq OWNED BY chado.nd_experiment_phenotype.nd_experiment_phenotype_id;


--
-- Name: nd_experiment_project; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_project (
    nd_experiment_project_id bigint NOT NULL,
    project_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_project OWNER TO www;

--
-- Name: TABLE nd_experiment_project; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_project IS 'Used to group together related nd_experiment records. All nd_experiments 
should be linked to at least one project.';


--
-- Name: nd_experiment_project_nd_experiment_project_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_project_nd_experiment_project_id_seq OWNER TO www;

--
-- Name: nd_experiment_project_nd_experiment_project_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq OWNED BY chado.nd_experiment_project.nd_experiment_project_id;


--
-- Name: nd_experiment_protocol; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_protocol (
    nd_experiment_protocol_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    nd_protocol_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_protocol OWNER TO www;

--
-- Name: TABLE nd_experiment_protocol; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_protocol IS 'Linking table: experiments to the protocols they involve.';


--
-- Name: nd_experiment_protocol_nd_experiment_protocol_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq OWNER TO www;

--
-- Name: nd_experiment_protocol_nd_experiment_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq OWNED BY chado.nd_experiment_protocol.nd_experiment_protocol_id;


--
-- Name: nd_experiment_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_pub (
    nd_experiment_pub_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_pub OWNER TO www;

--
-- Name: TABLE nd_experiment_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_pub IS 'Linking nd_experiment(s) to chado.tion(s)';


--
-- Name: nd_experiment_pub_nd_experiment_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_pub_nd_experiment_pub_id_seq OWNER TO www;

--
-- Name: nd_experiment_pub_nd_experiment_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq OWNED BY chado.nd_experiment_pub.nd_experiment_pub_id;


--
-- Name: nd_experiment_stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_stock (
    nd_experiment_stock_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_stock OWNER TO www;

--
-- Name: TABLE nd_experiment_stock; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_stock IS 'Part of a stock or a clone of a stock that is used in an experiment';


--
-- Name: COLUMN nd_experiment_stock.stock_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_experiment_stock.stock_id IS 'stock used in the extraction or the corresponding stock for the clone';


--
-- Name: nd_experiment_stock_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_stock_dbxref (
    nd_experiment_stock_dbxref_id bigint NOT NULL,
    nd_experiment_stock_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.nd_experiment_stock_dbxref OWNER TO www;

--
-- Name: TABLE nd_experiment_stock_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_stock_dbxref IS 'Cross-reference experiment_stock to accessions, images, etc';


--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq OWNER TO www;

--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq OWNED BY chado.nd_experiment_stock_dbxref.nd_experiment_stock_dbxref_id;


--
-- Name: nd_experiment_stock_nd_experiment_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_stock_nd_experiment_stock_id_seq OWNER TO www;

--
-- Name: nd_experiment_stock_nd_experiment_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq OWNED BY chado.nd_experiment_stock.nd_experiment_stock_id;


--
-- Name: nd_experiment_stockprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experiment_stockprop (
    nd_experiment_stockprop_id bigint NOT NULL,
    nd_experiment_stock_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.nd_experiment_stockprop OWNER TO www;

--
-- Name: TABLE nd_experiment_stockprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experiment_stockprop IS 'Property/value associations for experiment_stocks. This table can store the properties such as treatment';


--
-- Name: COLUMN nd_experiment_stockprop.nd_experiment_stock_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_experiment_stockprop.nd_experiment_stock_id IS 'The experiment_stock to which the property applies.';


--
-- Name: COLUMN nd_experiment_stockprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_experiment_stockprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_experiment_stockprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_experiment_stockprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_experiment_stockprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_experiment_stockprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_experiment_stockprop_nd_experiment_stockprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq OWNER TO www;

--
-- Name: nd_experiment_stockprop_nd_experiment_stockprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq OWNED BY chado.nd_experiment_stockprop.nd_experiment_stockprop_id;


--
-- Name: nd_experimentprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_experimentprop (
    nd_experimentprop_id bigint NOT NULL,
    nd_experiment_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.nd_experimentprop OWNER TO www;

--
-- Name: TABLE nd_experimentprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_experimentprop IS 'An nd_experiment can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, stockprop_c1, for
the combination of stock_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: nd_experimentprop_nd_experimentprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_experimentprop_nd_experimentprop_id_seq OWNER TO www;

--
-- Name: nd_experimentprop_nd_experimentprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq OWNED BY chado.nd_experimentprop.nd_experimentprop_id;


--
-- Name: nd_geolocation; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_geolocation (
    nd_geolocation_id bigint NOT NULL,
    description text,
    latitude real,
    longitude real,
    geodetic_datum character varying(32),
    altitude real
);


ALTER TABLE chado.nd_geolocation OWNER TO www;

--
-- Name: TABLE nd_geolocation; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_geolocation IS 'The geo-referencable location of the stock. NOTE: This entity is subject to change as a more general and possibly more OpenGIS-compliant geolocation module may be introduced into Chado.';


--
-- Name: COLUMN nd_geolocation.description; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocation.description IS 'A textual representation of the location, if this is the original georeference. Optional if the original georeference is available in lat/long coordinates.';


--
-- Name: COLUMN nd_geolocation.latitude; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocation.latitude IS 'The decimal latitude coordinate of the georeference, using positive and negative sign to indicate N and S, respectively.';


--
-- Name: COLUMN nd_geolocation.longitude; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocation.longitude IS 'The decimal longitude coordinate of the georeference, using positive and negative sign to indicate E and W, respectively.';


--
-- Name: COLUMN nd_geolocation.geodetic_datum; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocation.geodetic_datum IS 'The geodetic system on which the geo-reference coordinates are based. For geo-references measured between 1984 and 2010, this will typically be WGS84.';


--
-- Name: COLUMN nd_geolocation.altitude; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocation.altitude IS 'The altitude (elevation) of the location in meters. If the altitude is only known as a range, this is the average, and altitude_dev will hold half of the width of the range.';


--
-- Name: nd_geolocation_nd_geolocation_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_geolocation_nd_geolocation_id_seq OWNER TO www;

--
-- Name: nd_geolocation_nd_geolocation_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq OWNED BY chado.nd_geolocation.nd_geolocation_id;


--
-- Name: nd_geolocationprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_geolocationprop (
    nd_geolocationprop_id bigint NOT NULL,
    nd_geolocation_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.nd_geolocationprop OWNER TO www;

--
-- Name: TABLE nd_geolocationprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_geolocationprop IS 'Property/value associations for geolocations. This table can store the properties such as location and environment';


--
-- Name: COLUMN nd_geolocationprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocationprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_geolocationprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocationprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_geolocationprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_geolocationprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_geolocationprop_nd_geolocationprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_geolocationprop_nd_geolocationprop_id_seq OWNER TO www;

--
-- Name: nd_geolocationprop_nd_geolocationprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq OWNED BY chado.nd_geolocationprop.nd_geolocationprop_id;


--
-- Name: nd_protocol; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_protocol (
    nd_protocol_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.nd_protocol OWNER TO www;

--
-- Name: TABLE nd_protocol; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_protocol IS 'A protocol can be anything that is done as part of the experiment.';


--
-- Name: COLUMN nd_protocol.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_protocol.name IS 'The protocol name.';


--
-- Name: nd_protocol_nd_protocol_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_protocol_nd_protocol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_protocol_nd_protocol_id_seq OWNER TO www;

--
-- Name: nd_protocol_nd_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_protocol_nd_protocol_id_seq OWNED BY chado.nd_protocol.nd_protocol_id;


--
-- Name: nd_protocol_reagent; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_protocol_reagent (
    nd_protocol_reagent_id bigint NOT NULL,
    nd_protocol_id bigint NOT NULL,
    reagent_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.nd_protocol_reagent OWNER TO www;

--
-- Name: nd_protocol_reagent_nd_protocol_reagent_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq OWNER TO www;

--
-- Name: nd_protocol_reagent_nd_protocol_reagent_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq OWNED BY chado.nd_protocol_reagent.nd_protocol_reagent_id;


--
-- Name: nd_protocolprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_protocolprop (
    nd_protocolprop_id bigint NOT NULL,
    nd_protocol_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.nd_protocolprop OWNER TO www;

--
-- Name: TABLE nd_protocolprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_protocolprop IS 'Property/value associations for protocol.';


--
-- Name: COLUMN nd_protocolprop.nd_protocol_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_protocolprop.nd_protocol_id IS 'The protocol to which the property applies.';


--
-- Name: COLUMN nd_protocolprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_protocolprop.type_id IS 'The name of the property as a reference to a controlled vocabulary term.';


--
-- Name: COLUMN nd_protocolprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_protocolprop.value IS 'The value of the property.';


--
-- Name: COLUMN nd_protocolprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_protocolprop.rank IS 'The rank of the property value, if the property has an array of values.';


--
-- Name: nd_protocolprop_nd_protocolprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_protocolprop_nd_protocolprop_id_seq OWNER TO www;

--
-- Name: nd_protocolprop_nd_protocolprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq OWNED BY chado.nd_protocolprop.nd_protocolprop_id;


--
-- Name: nd_reagent; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_reagent (
    nd_reagent_id bigint NOT NULL,
    name character varying(80) NOT NULL,
    type_id bigint NOT NULL,
    feature_id bigint
);


ALTER TABLE chado.nd_reagent OWNER TO www;

--
-- Name: TABLE nd_reagent; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_reagent IS 'A reagent such as a primer, an enzyme, an adapter oligo, a linker oligo. Reagents are used in genotyping experiments, or in any other kind of experiment.';


--
-- Name: COLUMN nd_reagent.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent.name IS 'The name of the reagent. The name should be unique for a given type.';


--
-- Name: COLUMN nd_reagent.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent.type_id IS 'The type of the reagent, for example linker oligomer, or forward primer.';


--
-- Name: COLUMN nd_reagent.feature_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent.feature_id IS 'If the reagent is a primer, the feature that it corresponds to. More generally, the corresponding feature for any reagent that has a sequence that maps to another sequence.';


--
-- Name: nd_reagent_nd_reagent_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_reagent_nd_reagent_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_reagent_nd_reagent_id_seq OWNER TO www;

--
-- Name: nd_reagent_nd_reagent_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_reagent_nd_reagent_id_seq OWNED BY chado.nd_reagent.nd_reagent_id;


--
-- Name: nd_reagent_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_reagent_relationship (
    nd_reagent_relationship_id bigint NOT NULL,
    subject_reagent_id bigint NOT NULL,
    object_reagent_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.nd_reagent_relationship OWNER TO www;

--
-- Name: TABLE nd_reagent_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.nd_reagent_relationship IS 'Relationships between reagents. Some reagents form a group. i.e., they are used all together or not at all. Examples are adapter/linker/enzyme experiment reagents.';


--
-- Name: COLUMN nd_reagent_relationship.subject_reagent_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent_relationship.subject_reagent_id IS 'The subject reagent in the relationship. In parent/child terminology, the subject is the child. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: COLUMN nd_reagent_relationship.object_reagent_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent_relationship.object_reagent_id IS 'The object reagent in the relationship. In parent/child terminology, the object is the parent. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: COLUMN nd_reagent_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.nd_reagent_relationship.type_id IS 'The type (or predicate) of the relationship. For example, in "linkerA 3prime-overhang-linker enzymeA" linkerA is the subject, 3prime-overhand-linker is the type, and enzymeA is the object.';


--
-- Name: nd_reagent_relationship_nd_reagent_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq OWNER TO www;

--
-- Name: nd_reagent_relationship_nd_reagent_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq OWNED BY chado.nd_reagent_relationship.nd_reagent_relationship_id;


--
-- Name: nd_reagentprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.nd_reagentprop (
    nd_reagentprop_id bigint NOT NULL,
    nd_reagent_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.nd_reagentprop OWNER TO www;

--
-- Name: nd_reagentprop_nd_reagentprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.nd_reagentprop_nd_reagentprop_id_seq OWNER TO www;

--
-- Name: nd_reagentprop_nd_reagentprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq OWNED BY chado.nd_reagentprop.nd_reagentprop_id;


--
-- Name: organism; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism (
    organism_id bigint NOT NULL,
    abbreviation character varying(255),
    genus character varying(255) NOT NULL,
    species character varying(255) NOT NULL,
    common_name character varying(255),
    comment text,
    infraspecific_name character varying(1024),
    type_id bigint
);


ALTER TABLE chado.organism OWNER TO www;

--
-- Name: TABLE organism; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism IS 'The organismal taxonomic
classification. Note that phylogenies are represented using the
phylogeny module, and taxonomies can be represented using the cvterm
module or the phylogeny module.';


--
-- Name: COLUMN organism.species; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism.species IS 'A type of organism is always
uniquely identified by genus and species. When mapping from the NCBI
taxonomy names.dmp file, this column must be used where it
is present, as the common_name column is not always unique (e.g. environmental
samples). If a particular strain or subspecies is to be represented,
this is appended onto the species name. Follows standard NCBI taxonomy
pattern.';


--
-- Name: COLUMN organism.infraspecific_name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism.infraspecific_name IS 'The scientific name for any taxon 
below the rank of species.  The rank should be specified using the type_id field
and the name is provided here.';


--
-- Name: COLUMN organism.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism.type_id IS 'A controlled vocabulary term that
specifies the organism rank below species. It is used when an infraspecific 
name is provided.  Ideally, the rank should be a valid ICN name such as 
subspecies, varietas, subvarietas, forma and subforma';


--
-- Name: organism_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_cvterm (
    organism_cvterm_id bigint NOT NULL,
    organism_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.organism_cvterm OWNER TO www;

--
-- Name: TABLE organism_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism_cvterm IS 'organism to cvterm associations. Examples: taxonomic name';


--
-- Name: COLUMN organism_cvterm.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism_cvterm.rank IS 'Property-Value
ordering. Any organism_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used';


--
-- Name: organism_cvterm_organism_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_cvterm_organism_cvterm_id_seq OWNER TO www;

--
-- Name: organism_cvterm_organism_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq OWNED BY chado.organism_cvterm.organism_cvterm_id;


--
-- Name: organism_cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_cvtermprop (
    organism_cvtermprop_id bigint NOT NULL,
    organism_cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.organism_cvtermprop OWNER TO www;

--
-- Name: TABLE organism_cvtermprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism_cvtermprop IS 'Extensible properties for
organism to cvterm associations. Examples: qualifiers';


--
-- Name: COLUMN organism_cvtermprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. ';


--
-- Name: COLUMN organism_cvtermprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN organism_cvtermprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.organism_cvtermprop.rank IS 'Property-Value
ordering. Any organism_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used';


--
-- Name: organism_cvtermprop_organism_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_cvtermprop_organism_cvtermprop_id_seq OWNER TO www;

--
-- Name: organism_cvtermprop_organism_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq OWNED BY chado.organism_cvtermprop.organism_cvtermprop_id;


--
-- Name: organism_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_dbxref (
    organism_dbxref_id bigint NOT NULL,
    organism_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.organism_dbxref OWNER TO www;

--
-- Name: TABLE organism_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism_dbxref IS 'Links an organism to a dbxref.';


--
-- Name: organism_dbxref_organism_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_dbxref_organism_dbxref_id_seq OWNER TO www;

--
-- Name: organism_dbxref_organism_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq OWNED BY chado.organism_dbxref.organism_dbxref_id;


--
-- Name: organism_feature_count; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_feature_count (
    organism_id integer,
    genus character varying(255),
    species character varying(255),
    common_name character varying(255),
    num_features integer,
    cvterm_id integer,
    feature_type character varying(255)
);


ALTER TABLE chado.organism_feature_count OWNER TO www;

--
-- Name: organism_organism_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_organism_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_organism_id_seq OWNER TO www;

--
-- Name: organism_organism_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_organism_id_seq OWNED BY chado.organism.organism_id;


--
-- Name: organism_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_pub (
    organism_pub_id bigint NOT NULL,
    organism_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.organism_pub OWNER TO www;

--
-- Name: TABLE organism_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism_pub IS 'Attribution for organism.';


--
-- Name: organism_pub_organism_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_pub_organism_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_pub_organism_pub_id_seq OWNER TO www;

--
-- Name: organism_pub_organism_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_pub_organism_pub_id_seq OWNED BY chado.organism_pub.organism_pub_id;


--
-- Name: organism_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organism_relationship (
    organism_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.organism_relationship OWNER TO www;

--
-- Name: TABLE organism_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organism_relationship IS 'Specifies relationships between organisms 
that are not taxonomic. For example, in breeding, relationships such as 
"sterile_with", "incompatible_with", or "fertile_with" would be appropriate. Taxonomic
relatinoships should be housed in the phylogeny tables.';


--
-- Name: organism_relationship_organism_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organism_relationship_organism_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organism_relationship_organism_relationship_id_seq OWNER TO www;

--
-- Name: organism_relationship_organism_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organism_relationship_organism_relationship_id_seq OWNED BY chado.organism_relationship.organism_relationship_id;


--
-- Name: organismprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organismprop (
    organismprop_id bigint NOT NULL,
    organism_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.organismprop OWNER TO www;

--
-- Name: TABLE organismprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organismprop IS 'Tag-value properties - follows standard chado model.';


--
-- Name: organismprop_organismprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organismprop_organismprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organismprop_organismprop_id_seq OWNER TO www;

--
-- Name: organismprop_organismprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organismprop_organismprop_id_seq OWNED BY chado.organismprop.organismprop_id;


--
-- Name: organismprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.organismprop_pub (
    organismprop_pub_id bigint NOT NULL,
    organismprop_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.organismprop_pub OWNER TO www;

--
-- Name: TABLE organismprop_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.organismprop_pub IS 'Attribution for organismprop.';


--
-- Name: organismprop_pub_organismprop_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.organismprop_pub_organismprop_pub_id_seq OWNER TO www;

--
-- Name: organismprop_pub_organismprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq OWNED BY chado.organismprop_pub.organismprop_pub_id;


--
-- Name: phendesc; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phendesc (
    phendesc_id bigint NOT NULL,
    genotype_id bigint NOT NULL,
    environment_id bigint NOT NULL,
    description text NOT NULL,
    type_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.phendesc OWNER TO www;

--
-- Name: TABLE phendesc; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phendesc IS 'A summary of a _set_ of phenotypic statements for any one gcontext made in any one chado.tion.';


--
-- Name: phendesc_phendesc_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phendesc_phendesc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phendesc_phendesc_id_seq OWNER TO www;

--
-- Name: phendesc_phendesc_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phendesc_phendesc_id_seq OWNED BY chado.phendesc.phendesc_id;


--
-- Name: phenotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenotype (
    phenotype_id bigint NOT NULL,
    uniquename text NOT NULL,
    name text,
    observable_id bigint,
    attr_id bigint,
    value text,
    cvalue_id bigint,
    assay_id bigint
);


ALTER TABLE chado.phenotype OWNER TO www;

--
-- Name: TABLE phenotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phenotype IS 'A phenotypic statement, or a single
atomic phenotypic observation, is a controlled sentence describing
observable effects of non-wild type function. E.g. Obs=eye, attribute=color, cvalue=red.';


--
-- Name: COLUMN phenotype.observable_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phenotype.observable_id IS 'The entity: e.g. anatomy_part, biological_process.';


--
-- Name: COLUMN phenotype.attr_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phenotype.attr_id IS 'Phenotypic attribute (quality, property, attribute, character) - drawn from PATO.';


--
-- Name: COLUMN phenotype.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phenotype.value IS 'Value of attribute - unconstrained free text. Used only if cvalue_id is not appropriate.';


--
-- Name: COLUMN phenotype.cvalue_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phenotype.cvalue_id IS 'Phenotype attribute value (state).';


--
-- Name: COLUMN phenotype.assay_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phenotype.assay_id IS 'Evidence type.';


--
-- Name: phenotype_comparison; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenotype_comparison (
    phenotype_comparison_id bigint NOT NULL,
    genotype1_id bigint NOT NULL,
    environment1_id bigint NOT NULL,
    genotype2_id bigint NOT NULL,
    environment2_id bigint NOT NULL,
    phenotype1_id bigint NOT NULL,
    phenotype2_id bigint,
    pub_id bigint NOT NULL,
    organism_id bigint NOT NULL
);


ALTER TABLE chado.phenotype_comparison OWNER TO www;

--
-- Name: TABLE phenotype_comparison; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phenotype_comparison IS 'Comparison of phenotypes e.g., genotype1/environment1/phenotype1 "non-suppressible" with respect to genotype2/environment2/phenotype2.';


--
-- Name: phenotype_comparison_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenotype_comparison_cvterm (
    phenotype_comparison_cvterm_id bigint NOT NULL,
    phenotype_comparison_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.phenotype_comparison_cvterm OWNER TO www;

--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq OWNER TO www;

--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq OWNED BY chado.phenotype_comparison_cvterm.phenotype_comparison_cvterm_id;


--
-- Name: phenotype_comparison_phenotype_comparison_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenotype_comparison_phenotype_comparison_id_seq OWNER TO www;

--
-- Name: phenotype_comparison_phenotype_comparison_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq OWNED BY chado.phenotype_comparison.phenotype_comparison_id;


--
-- Name: phenotype_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenotype_cvterm (
    phenotype_cvterm_id bigint NOT NULL,
    phenotype_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.phenotype_cvterm OWNER TO www;

--
-- Name: TABLE phenotype_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phenotype_cvterm IS 'phenotype to cvterm associations.';


--
-- Name: phenotype_cvterm_phenotype_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenotype_cvterm_phenotype_cvterm_id_seq OWNER TO www;

--
-- Name: phenotype_cvterm_phenotype_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq OWNED BY chado.phenotype_cvterm.phenotype_cvterm_id;


--
-- Name: phenotype_phenotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenotype_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenotype_phenotype_id_seq OWNER TO www;

--
-- Name: phenotype_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenotype_phenotype_id_seq OWNED BY chado.phenotype.phenotype_id;


--
-- Name: phenotypeprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenotypeprop (
    phenotypeprop_id bigint NOT NULL,
    phenotype_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.phenotypeprop OWNER TO www;

--
-- Name: TABLE phenotypeprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phenotypeprop IS 'A phenotype can have any number of slot-value property tags attached to it. This is an alternative to hardcoding a list of columns in the relational schema, and is completely extensible. There is a unique constraint, phenotypeprop_c1, for the combination of phenotype_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: phenotypeprop_phenotypeprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenotypeprop_phenotypeprop_id_seq OWNER TO www;

--
-- Name: phenotypeprop_phenotypeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq OWNED BY chado.phenotypeprop.phenotypeprop_id;


--
-- Name: phenstatement; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phenstatement (
    phenstatement_id bigint NOT NULL,
    genotype_id bigint NOT NULL,
    environment_id bigint NOT NULL,
    phenotype_id bigint NOT NULL,
    type_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.phenstatement OWNER TO www;

--
-- Name: TABLE phenstatement; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phenstatement IS 'Phenotypes are things like "larval lethal".  Phenstatements are things like "dpp-1 is recessive larval lethal". So essentially phenstatement is a linking table expressing the relationship between genotype, environment, and phenotype.';


--
-- Name: phenstatement_phenstatement_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phenstatement_phenstatement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phenstatement_phenstatement_id_seq OWNER TO www;

--
-- Name: phenstatement_phenstatement_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phenstatement_phenstatement_id_seq OWNED BY chado.phenstatement.phenstatement_id;


--
-- Name: phylonode; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonode (
    phylonode_id bigint NOT NULL,
    phylotree_id bigint NOT NULL,
    parent_phylonode_id bigint,
    left_idx integer NOT NULL,
    right_idx integer NOT NULL,
    type_id bigint,
    feature_id bigint,
    label character varying(255),
    distance double precision
);


ALTER TABLE chado.phylonode OWNER TO www;

--
-- Name: TABLE phylonode; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylonode IS 'This is the most pervasive
       element in the phylogeny module, cataloging the "phylonodes" of
       tree graphs. Edges are implied by the parent_phylonode_id
       reflexive closure. For all nodes in a nested set implementation the left and right index will be *between* the parents left and right indexes.';


--
-- Name: COLUMN phylonode.parent_phylonode_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylonode.parent_phylonode_id IS 'Root phylonode can have null parent_phylonode_id value.';


--
-- Name: COLUMN phylonode.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylonode.type_id IS 'Type: e.g. root, interior, leaf.';


--
-- Name: COLUMN phylonode.feature_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylonode.feature_id IS 'Phylonodes can have optional features attached to them e.g. a protein or nucleotide sequence usually attached to a leaf of the phylotree for non-leaf nodes, the feature may be a feature that is an instance of SO:match; this feature is the alignment of all leaf features beneath it.';


--
-- Name: phylonode_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonode_dbxref (
    phylonode_dbxref_id bigint NOT NULL,
    phylonode_id bigint NOT NULL,
    dbxref_id bigint NOT NULL
);


ALTER TABLE chado.phylonode_dbxref OWNER TO www;

--
-- Name: TABLE phylonode_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylonode_dbxref IS 'For example, for orthology, paralogy group identifiers; could also be used for NCBI taxonomy; for sequences, refer to phylonode_feature, feature associated dbxrefs.';


--
-- Name: phylonode_dbxref_phylonode_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonode_dbxref_phylonode_dbxref_id_seq OWNER TO www;

--
-- Name: phylonode_dbxref_phylonode_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq OWNED BY chado.phylonode_dbxref.phylonode_dbxref_id;


--
-- Name: phylonode_organism; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonode_organism (
    phylonode_organism_id bigint NOT NULL,
    phylonode_id bigint NOT NULL,
    organism_id bigint NOT NULL
);


ALTER TABLE chado.phylonode_organism OWNER TO www;

--
-- Name: TABLE phylonode_organism; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylonode_organism IS 'This linking table should only be used for nodes in taxonomy trees; it provides a mapping between the node and an organism. One node can have zero or one organisms, one organism can have zero or more nodes (although typically it should only have one in the standard NCBI taxonomy tree).';


--
-- Name: COLUMN phylonode_organism.phylonode_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylonode_organism.phylonode_id IS 'One phylonode cannot refer to >1 organism.';


--
-- Name: phylonode_organism_phylonode_organism_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonode_organism_phylonode_organism_id_seq OWNER TO www;

--
-- Name: phylonode_organism_phylonode_organism_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq OWNED BY chado.phylonode_organism.phylonode_organism_id;


--
-- Name: phylonode_phylonode_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonode_phylonode_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonode_phylonode_id_seq OWNER TO www;

--
-- Name: phylonode_phylonode_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonode_phylonode_id_seq OWNED BY chado.phylonode.phylonode_id;


--
-- Name: phylonode_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonode_pub (
    phylonode_pub_id bigint NOT NULL,
    phylonode_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.phylonode_pub OWNER TO www;

--
-- Name: phylonode_pub_phylonode_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonode_pub_phylonode_pub_id_seq OWNER TO www;

--
-- Name: phylonode_pub_phylonode_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq OWNED BY chado.phylonode_pub.phylonode_pub_id;


--
-- Name: phylonode_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonode_relationship (
    phylonode_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL,
    rank integer,
    phylotree_id bigint NOT NULL
);


ALTER TABLE chado.phylonode_relationship OWNER TO www;

--
-- Name: TABLE phylonode_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylonode_relationship IS 'This is for 
relationships that are not strictly hierarchical; for example,
horizontal gene transfer. Most phylogenetic trees are strictly
hierarchical, nevertheless it is here for completeness.';


--
-- Name: phylonode_relationship_phylonode_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonode_relationship_phylonode_relationship_id_seq OWNER TO www;

--
-- Name: phylonode_relationship_phylonode_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq OWNED BY chado.phylonode_relationship.phylonode_relationship_id;


--
-- Name: phylonodeprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylonodeprop (
    phylonodeprop_id bigint NOT NULL,
    phylonode_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.phylonodeprop OWNER TO www;

--
-- Name: COLUMN phylonodeprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylonodeprop.type_id IS 'type_id could designate phylonode hierarchy relationships, for example: species taxonomy (kingdom, order, family, genus, species), "ortholog/paralog", "fold/superfold", etc.';


--
-- Name: phylonodeprop_phylonodeprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylonodeprop_phylonodeprop_id_seq OWNER TO www;

--
-- Name: phylonodeprop_phylonodeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq OWNED BY chado.phylonodeprop.phylonodeprop_id;


--
-- Name: phylotree; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylotree (
    phylotree_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    name character varying(255),
    type_id bigint,
    analysis_id bigint,
    comment text
);


ALTER TABLE chado.phylotree OWNER TO www;

--
-- Name: TABLE phylotree; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylotree IS 'Global anchor for phylogenetic tree.';


--
-- Name: COLUMN phylotree.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylotree.type_id IS 'Type: protein, nucleotide, taxonomy, for example. The type should be any SO type, or "taxonomy".';


--
-- Name: phylotree_phylotree_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylotree_phylotree_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylotree_phylotree_id_seq OWNER TO www;

--
-- Name: phylotree_phylotree_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylotree_phylotree_id_seq OWNED BY chado.phylotree.phylotree_id;


--
-- Name: phylotree_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylotree_pub (
    phylotree_pub_id bigint NOT NULL,
    phylotree_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.phylotree_pub OWNER TO www;

--
-- Name: TABLE phylotree_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylotree_pub IS 'Tracks citations global to the tree e.g. multiple sequence alignment supporting tree construction.';


--
-- Name: phylotree_pub_phylotree_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylotree_pub_phylotree_pub_id_seq OWNER TO www;

--
-- Name: phylotree_pub_phylotree_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq OWNED BY chado.phylotree_pub.phylotree_pub_id;


--
-- Name: phylotreeprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.phylotreeprop (
    phylotreeprop_id bigint NOT NULL,
    phylotree_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.phylotreeprop OWNER TO www;

--
-- Name: TABLE phylotreeprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.phylotreeprop IS 'A phylotree can have any number of slot-value property 
tags attached to it. This is an alternative to hardcoding a list of columns in the 
relational schema, and is completely extensible.';


--
-- Name: COLUMN phylotreeprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylotreeprop.type_id IS 'The name of the property/slot is a cvterm. 
The meaning of the property is defined in that cvterm.';


--
-- Name: COLUMN phylotreeprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylotreeprop.value IS 'The value of the property, represented as text. 
Numeric values are converted to their text representation. This is less efficient than 
using native database types, but is easier to query.';


--
-- Name: COLUMN phylotreeprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.phylotreeprop.rank IS 'Property-Value ordering. Any
phylotree can have multiple values for any particular property type 
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used';


--
-- Name: phylotreeprop_phylotreeprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.phylotreeprop_phylotreeprop_id_seq OWNER TO www;

--
-- Name: phylotreeprop_phylotreeprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq OWNED BY chado.phylotreeprop.phylotreeprop_id;


--
-- Name: project; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project (
    project_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text
);


ALTER TABLE chado.project OWNER TO www;

--
-- Name: TABLE project; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project IS 'Standard Chado flexible property table for projects.';


--
-- Name: project_analysis; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_analysis (
    project_analysis_id bigint NOT NULL,
    project_id bigint NOT NULL,
    analysis_id bigint NOT NULL
);


ALTER TABLE chado.project_analysis OWNER TO www;

--
-- Name: TABLE project_analysis; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_analysis IS 'Links an analysis to a project that may contain multiple analyses. 
The rank column can be used to specify a simple ordering in which analyses were executed.';


--
-- Name: project_analysis_project_analysis_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_analysis_project_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_analysis_project_analysis_id_seq OWNER TO www;

--
-- Name: project_analysis_project_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_analysis_project_analysis_id_seq OWNED BY chado.project_analysis.project_analysis_id;


--
-- Name: project_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_contact (
    project_contact_id bigint NOT NULL,
    project_id bigint NOT NULL,
    contact_id bigint NOT NULL
);


ALTER TABLE chado.project_contact OWNER TO www;

--
-- Name: TABLE project_contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_contact IS 'Linking table for associating projects and contacts.';


--
-- Name: project_contact_project_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_contact_project_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_contact_project_contact_id_seq OWNER TO www;

--
-- Name: project_contact_project_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_contact_project_contact_id_seq OWNED BY chado.project_contact.project_contact_id;


--
-- Name: project_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_dbxref (
    project_dbxref_id bigint NOT NULL,
    project_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.project_dbxref OWNER TO www;

--
-- Name: TABLE project_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_dbxref IS 'project_dbxref links a project to dbxrefs.';


--
-- Name: COLUMN project_dbxref.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.project_dbxref.is_current IS 'The is_current boolean indicates whether the linked dbxref is the current -official- dbxref for the linked project.';


--
-- Name: project_dbxref_project_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_dbxref_project_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_dbxref_project_dbxref_id_seq OWNER TO www;

--
-- Name: project_dbxref_project_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_dbxref_project_dbxref_id_seq OWNED BY chado.project_dbxref.project_dbxref_id;


--
-- Name: project_feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_feature (
    project_feature_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    project_id bigint NOT NULL
);


ALTER TABLE chado.project_feature OWNER TO www;

--
-- Name: TABLE project_feature; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_feature IS 'This table is intended associate records in the feature table with a project.';


--
-- Name: project_feature_project_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_feature_project_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_feature_project_feature_id_seq OWNER TO www;

--
-- Name: project_feature_project_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_feature_project_feature_id_seq OWNED BY chado.project_feature.project_feature_id;


--
-- Name: project_phenotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_phenotype (
    project_phenotype_id integer NOT NULL,
    project_id integer NOT NULL,
    phenotype_id integer NOT NULL
);


ALTER TABLE chado.project_phenotype OWNER TO www;

--
-- Name: project_phenotype_project_phenotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_phenotype_project_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_phenotype_project_phenotype_id_seq OWNER TO www;

--
-- Name: project_phenotype_project_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_phenotype_project_phenotype_id_seq OWNED BY chado.project_phenotype.project_phenotype_id;


--
-- Name: project_project_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_project_id_seq OWNER TO www;

--
-- Name: project_project_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_project_id_seq OWNED BY chado.project.project_id;


--
-- Name: project_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_pub (
    project_pub_id bigint NOT NULL,
    project_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.project_pub OWNER TO www;

--
-- Name: TABLE project_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_pub IS 'Linking table for associating projects and publications.';


--
-- Name: project_pub_project_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_pub_project_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_pub_project_pub_id_seq OWNER TO www;

--
-- Name: project_pub_project_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_pub_project_pub_id_seq OWNED BY chado.project_pub.project_pub_id;


--
-- Name: project_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_relationship (
    project_relationship_id bigint NOT NULL,
    subject_project_id bigint NOT NULL,
    object_project_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.project_relationship OWNER TO www;

--
-- Name: TABLE project_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_relationship IS 'Linking table for relating projects to each other.  For example, a
given project could be composed of several smaller subprojects';


--
-- Name: COLUMN project_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.project_relationship.type_id IS 'The cvterm type of the relationship being stated, such as "part of".';


--
-- Name: project_relationship_project_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_relationship_project_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_relationship_project_relationship_id_seq OWNER TO www;

--
-- Name: project_relationship_project_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.project_relationship_project_relationship_id_seq OWNED BY chado.project_relationship.project_relationship_id;


--
-- Name: project_stock_project_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.project_stock_project_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.project_stock_project_stock_id_seq OWNER TO www;

--
-- Name: project_stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.project_stock (
    project_stock_id bigint DEFAULT nextval('chado.project_stock_project_stock_id_seq'::regclass) NOT NULL,
    stock_id bigint NOT NULL,
    project_id bigint NOT NULL
);


ALTER TABLE chado.project_stock OWNER TO www;

--
-- Name: TABLE project_stock; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.project_stock IS 'This table is intended associate records in the stock table with a project.';


--
-- Name: projectprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.projectprop (
    projectprop_id bigint NOT NULL,
    project_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.projectprop OWNER TO www;

--
-- Name: projectprop_projectprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.projectprop_projectprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.projectprop_projectprop_id_seq OWNER TO www;

--
-- Name: projectprop_projectprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.projectprop_projectprop_id_seq OWNED BY chado.projectprop.projectprop_id;


--
-- Name: protocol; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.protocol (
    protocol_id bigint NOT NULL,
    type_id bigint NOT NULL,
    pub_id bigint,
    dbxref_id bigint,
    name text NOT NULL,
    uri text,
    protocoldescription text,
    hardwaredescription text,
    softwaredescription text
);


ALTER TABLE chado.protocol OWNER TO www;

--
-- Name: TABLE protocol; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.protocol IS 'Procedural notes on how data was prepared and processed.';


--
-- Name: protocol_protocol_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.protocol_protocol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.protocol_protocol_id_seq OWNER TO www;

--
-- Name: protocol_protocol_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.protocol_protocol_id_seq OWNED BY chado.protocol.protocol_id;


--
-- Name: protocolparam; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.protocolparam (
    protocolparam_id bigint NOT NULL,
    protocol_id bigint NOT NULL,
    name text NOT NULL,
    datatype_id bigint,
    unittype_id bigint,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.protocolparam OWNER TO www;

--
-- Name: TABLE protocolparam; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.protocolparam IS 'Parameters related to a
protocol. For example, if the protocol is a soak, this might include attributes of bath temperature and duration.';


--
-- Name: protocolparam_protocolparam_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.protocolparam_protocolparam_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.protocolparam_protocolparam_id_seq OWNER TO www;

--
-- Name: protocolparam_protocolparam_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.protocolparam_protocolparam_id_seq OWNED BY chado.protocolparam.protocolparam_id;


--
-- Name: pub_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pub_dbxref (
    pub_dbxref_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.pub_dbxref OWNER TO www;

--
-- Name: TABLE pub_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pub_dbxref IS 'Handle links to repositories,
e.g. Pubmed, Biosis, zoorec, OCLC, Medline, ISSN, coden...';


--
-- Name: pub_dbxref_pub_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pub_dbxref_pub_dbxref_id_seq OWNER TO www;

--
-- Name: pub_dbxref_pub_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq OWNED BY chado.pub_dbxref.pub_dbxref_id;


--
-- Name: pub_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pub_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pub_pub_id_seq OWNER TO www;

--
-- Name: pub_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pub_pub_id_seq OWNED BY chado.pub.pub_id;


--
-- Name: pub_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pub_relationship (
    pub_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL
);


ALTER TABLE chado.pub_relationship OWNER TO www;

--
-- Name: TABLE pub_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pub_relationship IS 'Handle relationships between
publications, e.g. when one publication makes others obsolete, when one
publication contains errata with respect to other publication(s), or
when one publication also appears in another pub.';


--
-- Name: pub_relationship_pub_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pub_relationship_pub_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pub_relationship_pub_relationship_id_seq OWNER TO www;

--
-- Name: pub_relationship_pub_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pub_relationship_pub_relationship_id_seq OWNED BY chado.pub_relationship.pub_relationship_id;


--
-- Name: pubauthor; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pubauthor (
    pubauthor_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    rank integer NOT NULL,
    editor boolean DEFAULT false,
    surname character varying(100) NOT NULL,
    givennames character varying(100),
    suffix character varying(100)
);


ALTER TABLE chado.pubauthor OWNER TO www;

--
-- Name: TABLE pubauthor; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pubauthor IS 'An author for a chado.tion. Note the denormalisation (hence lack of _ in table name) - this is deliberate as it is in general too hard to assign IDs to authors.';


--
-- Name: COLUMN pubauthor.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pubauthor.rank IS 'Order of author in author list for this pub - order is important.';


--
-- Name: COLUMN pubauthor.editor; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pubauthor.editor IS 'Indicates whether the author is an editor for linked chado.tion. Note: this is a boolean field but does not follow the normal chado convention for naming booleans.';


--
-- Name: COLUMN pubauthor.givennames; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pubauthor.givennames IS 'First name, initials';


--
-- Name: COLUMN pubauthor.suffix; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.pubauthor.suffix IS 'Jr., Sr., etc';


--
-- Name: pubauthor_contact; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pubauthor_contact (
    pubauthor_contact_id bigint NOT NULL,
    contact_id bigint NOT NULL,
    pubauthor_id bigint NOT NULL
);


ALTER TABLE chado.pubauthor_contact OWNER TO www;

--
-- Name: TABLE pubauthor_contact; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pubauthor_contact IS 'An author on a publication may have a corresponding entry in the contact table and this table can link the two.';


--
-- Name: pubauthor_contact_pubauthor_contact_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pubauthor_contact_pubauthor_contact_id_seq OWNER TO www;

--
-- Name: pubauthor_contact_pubauthor_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq OWNED BY chado.pubauthor_contact.pubauthor_contact_id;


--
-- Name: pubauthor_pubauthor_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pubauthor_pubauthor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pubauthor_pubauthor_id_seq OWNER TO www;

--
-- Name: pubauthor_pubauthor_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pubauthor_pubauthor_id_seq OWNED BY chado.pubauthor.pubauthor_id;


--
-- Name: pubprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.pubprop (
    pubprop_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text NOT NULL,
    rank integer
);


ALTER TABLE chado.pubprop OWNER TO www;

--
-- Name: TABLE pubprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.pubprop IS 'Property-value pairs for a pub. Follows standard chado pattern.';


--
-- Name: pubprop_pubprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.pubprop_pubprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.pubprop_pubprop_id_seq OWNER TO www;

--
-- Name: pubprop_pubprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.pubprop_pubprop_id_seq OWNED BY chado.pubprop.pubprop_id;


--
-- Name: qtl_map_position; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.qtl_map_position (
    qtl_id integer NOT NULL,
    qtl_nid integer,
    qtl_symbol text NOT NULL,
    map_name text,
    map_nid integer,
    lg text NOT NULL,
    lg_nid integer NOT NULL,
    qtl_peak real,
    left_end real,
    right_end real,
    int_calc_meth text,
    mapping_population text,
    mapping_population_nid integer,
    parent1 text,
    parent1_nid integer,
    parent2 text,
    parent2_nid integer,
    lis_lg_map_accession text,
    lis_map_accession text
);


ALTER TABLE chado.qtl_map_position OWNER TO www;

--
-- Name: qtl_search; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.qtl_search (
    qtl_id integer,
    qtl_nid integer,
    qtl_name text NOT NULL,
    expt_qtl_symbol text,
    organism character varying(510) NOT NULL,
    common_name character varying(510) NOT NULL,
    org_nid integer NOT NULL,
    mnemonic character varying(10) NOT NULL,
    citation text NOT NULL,
    pub_nid integer NOT NULL,
    expt_trait_name text,
    expt_trait_description text,
    trait_unit character varying(255),
    trait_class text,
    qtl_symbol text,
    trait_name character varying(255),
    trait_description text,
    obo_terms text,
    favorable_allele_source text,
    fas_nid integer,
    treatment text,
    analysis_method text,
    lod real,
    likelihood_ratio real,
    marker_r2 real,
    total_r2 real,
    additivity real,
    nearest_marker text,
    nearest_marker_nid integer,
    flanking_marker_low text,
    flanking_marker_low_nid integer,
    flanking_marker_high text,
    flanking_marker_high_nid integer,
    comment text
);


ALTER TABLE chado.qtl_search OWNER TO www;

--
-- Name: quantification; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.quantification (
    quantification_id bigint NOT NULL,
    acquisition_id bigint NOT NULL,
    operator_id bigint,
    protocol_id bigint,
    analysis_id bigint NOT NULL,
    quantificationdate timestamp without time zone DEFAULT now(),
    name text,
    uri text
);


ALTER TABLE chado.quantification OWNER TO www;

--
-- Name: TABLE quantification; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.quantification IS 'Quantification is the transformation of an image acquisition to numeric data. This typically involves statistical procedures.';


--
-- Name: quantification_quantification_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.quantification_quantification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.quantification_quantification_id_seq OWNER TO www;

--
-- Name: quantification_quantification_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.quantification_quantification_id_seq OWNED BY chado.quantification.quantification_id;


--
-- Name: quantification_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.quantification_relationship (
    quantification_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    type_id bigint NOT NULL,
    object_id bigint NOT NULL
);


ALTER TABLE chado.quantification_relationship OWNER TO www;

--
-- Name: TABLE quantification_relationship; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.quantification_relationship IS 'There may be multiple rounds of quantification, this allows us to keep an audit trail of what values went where.';


--
-- Name: quantification_relationship_quantification_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.quantification_relationship_quantification_relationship_id_seq OWNER TO www;

--
-- Name: quantification_relationship_quantification_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq OWNED BY chado.quantification_relationship.quantification_relationship_id;


--
-- Name: quantificationprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.quantificationprop (
    quantificationprop_id bigint NOT NULL,
    quantification_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.quantificationprop OWNER TO www;

--
-- Name: TABLE quantificationprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.quantificationprop IS 'Extra quantification properties that are not accounted for in quantification.';


--
-- Name: quantificationprop_quantificationprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.quantificationprop_quantificationprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.quantificationprop_quantificationprop_id_seq OWNER TO www;

--
-- Name: quantificationprop_quantificationprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.quantificationprop_quantificationprop_id_seq OWNED BY chado.quantificationprop.quantificationprop_id;


--
-- Name: stats_paths_to_root; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.stats_paths_to_root AS
 SELECT cvtermpath.subject_id AS cvterm_id,
    count(DISTINCT cvtermpath.cvtermpath_id) AS total_paths,
    avg(cvtermpath.pathdistance) AS avg_distance,
    min(cvtermpath.pathdistance) AS min_distance,
    max(cvtermpath.pathdistance) AS max_distance
   FROM (chado.cvtermpath
     JOIN chado.cv_root ON ((cvtermpath.object_id = cv_root.root_cvterm_id)))
  GROUP BY cvtermpath.subject_id;


ALTER TABLE chado.stats_paths_to_root OWNER TO www;

--
-- Name: VIEW stats_paths_to_root; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.stats_paths_to_root IS 'per-cvterm statistics on its
placement in the DAG relative to the root. There may be multiple paths
from any term to the root. This gives the total number of paths, and
the average minimum and maximum distances. Here distance is defined by
cvtermpath.pathdistance';


--
-- Name: stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock (
    stock_id bigint NOT NULL,
    dbxref_id bigint,
    organism_id bigint,
    name character varying(255),
    uniquename text NOT NULL,
    description text,
    type_id bigint NOT NULL,
    is_obsolete boolean DEFAULT false NOT NULL
);


ALTER TABLE chado.stock OWNER TO www;

--
-- Name: TABLE stock; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock IS 'Any stock can be globally identified by the
combination of organism, uniquename and stock type. A stock is the physical entities, either living or preserved, held by collections. Stocks belong to a collection; they have IDs, type, organism, description and may have a genotype.';


--
-- Name: COLUMN stock.dbxref_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock.dbxref_id IS 'The dbxref_id is an optional primary stable identifier for this stock. Secondary indentifiers and external dbxrefs go in table: stock_dbxref.';


--
-- Name: COLUMN stock.organism_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock.organism_id IS 'The organism_id is the organism to which the stock belongs. This column should only be left blank if the organism cannot be determined.';


--
-- Name: COLUMN stock.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock.name IS 'The name is a human-readable local name for a stock.';


--
-- Name: COLUMN stock.description; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock.description IS 'The description is the genetic description provided in the stock list.';


--
-- Name: COLUMN stock.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock.type_id IS 'The type_id foreign key links to a controlled vocabulary of stock types. The would include living stock, genomic DNA, preserved specimen. Secondary cvterms for stocks would go in stock_cvterm.';


--
-- Name: stock_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_cvterm (
    stock_cvterm_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint NOT NULL,
    is_not boolean DEFAULT false NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_cvterm OWNER TO www;

--
-- Name: TABLE stock_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_cvterm IS 'stock_cvterm links a stock to cvterms. This is for secondary cvterms; primary cvterms should use stock.type_id.';


--
-- Name: stock_cvterm_stock_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_cvterm_stock_cvterm_id_seq OWNER TO www;

--
-- Name: stock_cvterm_stock_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq OWNED BY chado.stock_cvterm.stock_cvterm_id;


--
-- Name: stock_cvtermprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_cvtermprop (
    stock_cvtermprop_id bigint NOT NULL,
    stock_cvterm_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_cvtermprop OWNER TO www;

--
-- Name: TABLE stock_cvtermprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_cvtermprop IS 'Extensible properties for
stock to cvterm associations. Examples: GO evidence codes;
qualifiers; metadata such as the date on which the entry was curated
and the source of the association. See the stockprop table for
meanings of type_id, value and rank.';


--
-- Name: COLUMN stock_cvtermprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_cvtermprop.type_id IS 'The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. cvterms may come from the OBO evidence code cv.';


--
-- Name: COLUMN stock_cvtermprop.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_cvtermprop.value IS 'The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.';


--
-- Name: COLUMN stock_cvtermprop.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_cvtermprop.rank IS 'Property-Value
ordering. Any stock_cvterm can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.';


--
-- Name: stock_cvtermprop_stock_cvtermprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_cvtermprop_stock_cvtermprop_id_seq OWNER TO www;

--
-- Name: stock_cvtermprop_stock_cvtermprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq OWNED BY chado.stock_cvtermprop.stock_cvtermprop_id;


--
-- Name: stock_dbxref; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_dbxref (
    stock_dbxref_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    dbxref_id bigint NOT NULL,
    is_current boolean DEFAULT true NOT NULL
);


ALTER TABLE chado.stock_dbxref OWNER TO www;

--
-- Name: TABLE stock_dbxref; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_dbxref IS 'stock_dbxref links a stock to dbxrefs. This is for secondary identifiers; primary identifiers should use stock.dbxref_id.';


--
-- Name: COLUMN stock_dbxref.is_current; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_dbxref.is_current IS 'The is_current boolean indicates whether the linked dbxref is the current -official- dbxref for the linked stock.';


--
-- Name: stock_dbxref_stock_dbxref_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_dbxref_stock_dbxref_id_seq OWNER TO www;

--
-- Name: stock_dbxref_stock_dbxref_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq OWNED BY chado.stock_dbxref.stock_dbxref_id;


--
-- Name: stock_dbxrefprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_dbxrefprop (
    stock_dbxrefprop_id bigint NOT NULL,
    stock_dbxref_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_dbxrefprop OWNER TO www;

--
-- Name: TABLE stock_dbxrefprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_dbxrefprop IS 'A stock_dbxref can have any number of
slot-value property tags attached to it. This is useful for storing properties related to dbxref annotations of stocks, such as evidence codes, and references, and metadata, such as create/modify dates. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, stock_dbxrefprop_c1, for
the combination of stock_dbxref_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: stock_dbxrefprop_stock_dbxrefprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq OWNER TO www;

--
-- Name: stock_dbxrefprop_stock_dbxrefprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq OWNED BY chado.stock_dbxrefprop.stock_dbxrefprop_id;


--
-- Name: stock_eimage; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_eimage (
    stock_eimage_id integer NOT NULL,
    stock_id integer NOT NULL,
    eimage_id integer NOT NULL
);


ALTER TABLE chado.stock_eimage OWNER TO www;

--
-- Name: stock_eimage_stock_eimage_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_eimage_stock_eimage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_eimage_stock_eimage_id_seq OWNER TO www;

--
-- Name: stock_eimage_stock_eimage_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_eimage_stock_eimage_id_seq OWNED BY chado.stock_eimage.stock_eimage_id;


--
-- Name: stock_feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_feature (
    stock_feature_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    type_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_feature OWNER TO www;

--
-- Name: TABLE stock_feature; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_feature IS 'Links a stock to a feature.';


--
-- Name: stock_feature_stock_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_feature_stock_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_feature_stock_feature_id_seq OWNER TO www;

--
-- Name: stock_feature_stock_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_feature_stock_feature_id_seq OWNED BY chado.stock_feature.stock_feature_id;


--
-- Name: stock_featuremap_stock_featuremap_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_featuremap_stock_featuremap_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_featuremap_stock_featuremap_id_seq OWNER TO www;

--
-- Name: stock_featuremap; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_featuremap (
    stock_featuremap_id bigint DEFAULT nextval('chado.stock_featuremap_stock_featuremap_id_seq'::regclass) NOT NULL,
    featuremap_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    type_id bigint
);


ALTER TABLE chado.stock_featuremap OWNER TO www;

--
-- Name: TABLE stock_featuremap; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_featuremap IS 'Links a featuremap to a stock.';


--
-- Name: stock_genotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_genotype (
    stock_genotype_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    genotype_id bigint NOT NULL
);


ALTER TABLE chado.stock_genotype OWNER TO www;

--
-- Name: TABLE stock_genotype; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_genotype IS 'Simple table linking a stock to
a genotype. Features with genotypes can be linked to stocks thru feature_genotype -> genotype -> stock_genotype -> stock.';


--
-- Name: stock_genotype_stock_genotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_genotype_stock_genotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_genotype_stock_genotype_id_seq OWNER TO www;

--
-- Name: stock_genotype_stock_genotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_genotype_stock_genotype_id_seq OWNED BY chado.stock_genotype.stock_genotype_id;


--
-- Name: stock_library_stock_library_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_library_stock_library_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_library_stock_library_id_seq OWNER TO www;

--
-- Name: stock_library; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_library (
    stock_library_id bigint DEFAULT nextval('chado.stock_library_stock_library_id_seq'::regclass) NOT NULL,
    library_id bigint NOT NULL,
    stock_id bigint NOT NULL
);


ALTER TABLE chado.stock_library OWNER TO www;

--
-- Name: TABLE stock_library; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_library IS 'Links a stock with a library.';


--
-- Name: stock_organism; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_organism (
    stock_organism_id integer NOT NULL,
    stock_id integer NOT NULL,
    organism_id integer NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_organism OWNER TO www;

--
-- Name: stock_organism_stock_organism_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_organism_stock_organism_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_organism_stock_organism_id_seq OWNER TO www;

--
-- Name: stock_organism_stock_organism_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_organism_stock_organism_id_seq OWNED BY chado.stock_organism.stock_organism_id;


--
-- Name: stock_phenotype; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_phenotype (
    stock_phenotype_id integer NOT NULL,
    stock_id integer NOT NULL,
    phenotype_id integer NOT NULL
);


ALTER TABLE chado.stock_phenotype OWNER TO www;

--
-- Name: stock_phenotype_stock_phenotype_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_phenotype_stock_phenotype_id_seq OWNER TO www;

--
-- Name: stock_phenotype_stock_phenotype_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq OWNED BY chado.stock_phenotype.stock_phenotype_id;


--
-- Name: stock_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_pub (
    stock_pub_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.stock_pub OWNER TO www;

--
-- Name: TABLE stock_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_pub IS 'Provenance. Linking table between stocks and, for example, a stocklist computer file.';


--
-- Name: stock_pub_stock_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_pub_stock_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_pub_stock_pub_id_seq OWNER TO www;

--
-- Name: stock_pub_stock_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_pub_stock_pub_id_seq OWNED BY chado.stock_pub.stock_pub_id;


--
-- Name: stock_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_relationship (
    stock_relationship_id bigint NOT NULL,
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stock_relationship OWNER TO www;

--
-- Name: COLUMN stock_relationship.subject_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_relationship.subject_id IS 'stock_relationship.subject_id is the subject of the subj-predicate-obj sentence. This is typically the substock.';


--
-- Name: COLUMN stock_relationship.object_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_relationship.object_id IS 'stock_relationship.object_id is the object of the subj-predicate-obj sentence. This is typically the container stock.';


--
-- Name: COLUMN stock_relationship.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_relationship.type_id IS 'stock_relationship.type_id is relationship type between subject and object. This is a cvterm, typically from the OBO relationship ontology, although other relationship types are allowed.';


--
-- Name: COLUMN stock_relationship.value; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_relationship.value IS 'stock_relationship.value is for additional notes or comments.';


--
-- Name: COLUMN stock_relationship.rank; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stock_relationship.rank IS 'stock_relationship.rank is the ordering of subject stocks with respect to the object stock may be important where rank is used to order these; starts from zero.';


--
-- Name: stock_relationship_cvterm; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_relationship_cvterm (
    stock_relationship_cvterm_id bigint NOT NULL,
    stock_relationship_id bigint NOT NULL,
    cvterm_id bigint NOT NULL,
    pub_id bigint
);


ALTER TABLE chado.stock_relationship_cvterm OWNER TO www;

--
-- Name: TABLE stock_relationship_cvterm; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_relationship_cvterm IS 'For germplasm maintenance and pedigree data, stock_relationship. type_id will record cvterms such as "is a female parent of", "a parent for mutation", "is a group_id of", "is a source_id of", etc The cvterms for higher categories such as "generative", "derivative" or "maintenance" can be stored in table stock_relationship_cvterm';


--
-- Name: stock_relationship_cvterm_stock_relationship_cvterm_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq OWNER TO www;

--
-- Name: stock_relationship_cvterm_stock_relationship_cvterm_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq OWNED BY chado.stock_relationship_cvterm.stock_relationship_cvterm_id;


--
-- Name: stock_relationship_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_relationship_pub (
    stock_relationship_pub_id bigint NOT NULL,
    stock_relationship_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.stock_relationship_pub OWNER TO www;

--
-- Name: TABLE stock_relationship_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stock_relationship_pub IS 'Provenance. Attach optional evidence to a stock_relationship in the form of a chado.tion.';


--
-- Name: stock_relationship_pub_stock_relationship_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_relationship_pub_stock_relationship_pub_id_seq OWNER TO www;

--
-- Name: stock_relationship_pub_stock_relationship_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq OWNED BY chado.stock_relationship_pub.stock_relationship_pub_id;


--
-- Name: stock_relationship_stock_relationship_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_relationship_stock_relationship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_relationship_stock_relationship_id_seq OWNER TO www;

--
-- Name: stock_relationship_stock_relationship_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_relationship_stock_relationship_id_seq OWNED BY chado.stock_relationship.stock_relationship_id;


--
-- Name: stock_search; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stock_search (
    nid integer,
    stock_id integer,
    stockname text,
    stocktype text,
    organism_id integer,
    common_name text,
    genus text,
    species text,
    collection text
);


ALTER TABLE chado.stock_search OWNER TO www;

--
-- Name: stock_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stock_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stock_stock_id_seq OWNER TO www;

--
-- Name: stock_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stock_stock_id_seq OWNED BY chado.stock.stock_id;


--
-- Name: stockcollection; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockcollection (
    stockcollection_id bigint NOT NULL,
    type_id bigint NOT NULL,
    contact_id bigint,
    name character varying(255),
    uniquename text NOT NULL
);


ALTER TABLE chado.stockcollection OWNER TO www;

--
-- Name: TABLE stockcollection; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockcollection IS 'The lab or stock center distributing the stocks in their collection.';


--
-- Name: COLUMN stockcollection.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stockcollection.type_id IS 'type_id is the collection type cv.';


--
-- Name: COLUMN stockcollection.contact_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stockcollection.contact_id IS 'contact_id links to the contact information for the collection.';


--
-- Name: COLUMN stockcollection.name; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stockcollection.name IS 'name is the collection.';


--
-- Name: COLUMN stockcollection.uniquename; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stockcollection.uniquename IS 'uniqename is the value of the collection cv.';


--
-- Name: stockcollection_db_stockcollection_db_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockcollection_db_stockcollection_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockcollection_db_stockcollection_db_id_seq OWNER TO www;

--
-- Name: stockcollection_db; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockcollection_db (
    stockcollection_db_id bigint DEFAULT nextval('chado.stockcollection_db_stockcollection_db_id_seq'::regclass) NOT NULL,
    stockcollection_id bigint NOT NULL,
    db_id bigint NOT NULL
);


ALTER TABLE chado.stockcollection_db OWNER TO www;

--
-- Name: TABLE stockcollection_db; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockcollection_db IS 'Stock collections may be respresented 
by an external online database. This table associates a stock collection with 
a database where its member stocks can be found. Individual stock that are part 
of this collction should have entries in the stock_dbxref table with the same 
db_id record';


--
-- Name: stockcollection_stock; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockcollection_stock (
    stockcollection_stock_id bigint NOT NULL,
    stockcollection_id bigint NOT NULL,
    stock_id bigint NOT NULL
);


ALTER TABLE chado.stockcollection_stock OWNER TO www;

--
-- Name: TABLE stockcollection_stock; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockcollection_stock IS 'stockcollection_stock links
a stock collection to the stocks which are contained in the collection.';


--
-- Name: stockcollection_stock_stockcollection_stock_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockcollection_stock_stockcollection_stock_id_seq OWNER TO www;

--
-- Name: stockcollection_stock_stockcollection_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq OWNED BY chado.stockcollection_stock.stockcollection_stock_id;


--
-- Name: stockcollection_stockcollection_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockcollection_stockcollection_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockcollection_stockcollection_id_seq OWNER TO www;

--
-- Name: stockcollection_stockcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stockcollection_stockcollection_id_seq OWNED BY chado.stockcollection.stockcollection_id;


--
-- Name: stockcollectionprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockcollectionprop (
    stockcollectionprop_id bigint NOT NULL,
    stockcollection_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stockcollectionprop OWNER TO www;

--
-- Name: TABLE stockcollectionprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockcollectionprop IS 'The table stockcollectionprop
contains the value of the stock collection such as website/email URLs;
the value of the stock collection order URLs.';


--
-- Name: COLUMN stockcollectionprop.type_id; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON COLUMN chado.stockcollectionprop.type_id IS 'The cv for the type_id is "stockcollection property type".';


--
-- Name: stockcollectionprop_stockcollectionprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockcollectionprop_stockcollectionprop_id_seq OWNER TO www;

--
-- Name: stockcollectionprop_stockcollectionprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq OWNED BY chado.stockcollectionprop.stockcollectionprop_id;


--
-- Name: stockprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockprop (
    stockprop_id bigint NOT NULL,
    stock_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.stockprop OWNER TO www;

--
-- Name: TABLE stockprop; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockprop IS 'A stock can have any number of
slot-value property tags attached to it. This is an alternative to
hardcoding a list of columns in the relational schema, and is
completely extensible. There is a unique constraint, stockprop_c1, for
the combination of stock_id, rank, and type_id. Multivalued property-value pairs must be differentiated by rank.';


--
-- Name: stockprop_pub; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.stockprop_pub (
    stockprop_pub_id bigint NOT NULL,
    stockprop_id bigint NOT NULL,
    pub_id bigint NOT NULL
);


ALTER TABLE chado.stockprop_pub OWNER TO www;

--
-- Name: TABLE stockprop_pub; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.stockprop_pub IS 'Provenance. Any stockprop assignment can optionally be supported by a chado.tion.';


--
-- Name: stockprop_pub_stockprop_pub_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockprop_pub_stockprop_pub_id_seq OWNER TO www;

--
-- Name: stockprop_pub_stockprop_pub_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq OWNED BY chado.stockprop_pub.stockprop_pub_id;


--
-- Name: stockprop_stockprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.stockprop_stockprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.stockprop_stockprop_id_seq OWNER TO www;

--
-- Name: stockprop_stockprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.stockprop_stockprop_id_seq OWNED BY chado.stockprop.stockprop_id;


--
-- Name: study; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.study (
    study_id bigint NOT NULL,
    contact_id bigint NOT NULL,
    pub_id bigint,
    dbxref_id bigint,
    name text NOT NULL,
    description text
);


ALTER TABLE chado.study OWNER TO www;

--
-- Name: study_assay; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.study_assay (
    study_assay_id bigint NOT NULL,
    study_id bigint NOT NULL,
    assay_id bigint NOT NULL
);


ALTER TABLE chado.study_assay OWNER TO www;

--
-- Name: study_assay_study_assay_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.study_assay_study_assay_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.study_assay_study_assay_id_seq OWNER TO www;

--
-- Name: study_assay_study_assay_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.study_assay_study_assay_id_seq OWNED BY chado.study_assay.study_assay_id;


--
-- Name: study_study_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.study_study_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.study_study_id_seq OWNER TO www;

--
-- Name: study_study_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.study_study_id_seq OWNED BY chado.study.study_id;


--
-- Name: studydesign; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studydesign (
    studydesign_id bigint NOT NULL,
    study_id bigint NOT NULL,
    description text
);


ALTER TABLE chado.studydesign OWNER TO www;

--
-- Name: studydesign_studydesign_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studydesign_studydesign_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studydesign_studydesign_id_seq OWNER TO www;

--
-- Name: studydesign_studydesign_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studydesign_studydesign_id_seq OWNED BY chado.studydesign.studydesign_id;


--
-- Name: studydesignprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studydesignprop (
    studydesignprop_id bigint NOT NULL,
    studydesign_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.studydesignprop OWNER TO www;

--
-- Name: studydesignprop_studydesignprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studydesignprop_studydesignprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studydesignprop_studydesignprop_id_seq OWNER TO www;

--
-- Name: studydesignprop_studydesignprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studydesignprop_studydesignprop_id_seq OWNED BY chado.studydesignprop.studydesignprop_id;


--
-- Name: studyfactor; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studyfactor (
    studyfactor_id bigint NOT NULL,
    studydesign_id bigint NOT NULL,
    type_id bigint,
    name text NOT NULL,
    description text
);


ALTER TABLE chado.studyfactor OWNER TO www;

--
-- Name: studyfactor_studyfactor_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studyfactor_studyfactor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studyfactor_studyfactor_id_seq OWNER TO www;

--
-- Name: studyfactor_studyfactor_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studyfactor_studyfactor_id_seq OWNED BY chado.studyfactor.studyfactor_id;


--
-- Name: studyfactorvalue; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studyfactorvalue (
    studyfactorvalue_id bigint NOT NULL,
    studyfactor_id bigint NOT NULL,
    assay_id bigint NOT NULL,
    factorvalue text,
    name text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.studyfactorvalue OWNER TO www;

--
-- Name: studyfactorvalue_studyfactorvalue_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studyfactorvalue_studyfactorvalue_id_seq OWNER TO www;

--
-- Name: studyfactorvalue_studyfactorvalue_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq OWNED BY chado.studyfactorvalue.studyfactorvalue_id;


--
-- Name: studyprop; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studyprop (
    studyprop_id bigint NOT NULL,
    study_id bigint NOT NULL,
    type_id bigint NOT NULL,
    value text,
    rank integer DEFAULT 0 NOT NULL
);


ALTER TABLE chado.studyprop OWNER TO www;

--
-- Name: studyprop_feature; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.studyprop_feature (
    studyprop_feature_id bigint NOT NULL,
    studyprop_id bigint NOT NULL,
    feature_id bigint NOT NULL,
    type_id bigint
);


ALTER TABLE chado.studyprop_feature OWNER TO www;

--
-- Name: studyprop_feature_studyprop_feature_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studyprop_feature_studyprop_feature_id_seq OWNER TO www;

--
-- Name: studyprop_feature_studyprop_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq OWNED BY chado.studyprop_feature.studyprop_feature_id;


--
-- Name: studyprop_studyprop_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.studyprop_studyprop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.studyprop_studyprop_id_seq OWNER TO www;

--
-- Name: studyprop_studyprop_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.studyprop_studyprop_id_seq OWNED BY chado.studyprop.studyprop_id;


--
-- Name: synonym_synonym_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.synonym_synonym_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.synonym_synonym_id_seq OWNER TO www;

--
-- Name: synonym_synonym_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.synonym_synonym_id_seq OWNED BY chado.synonym.synonym_id;


--
-- Name: tableinfo; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tableinfo (
    tableinfo_id bigint NOT NULL,
    name character varying(30) NOT NULL,
    primary_key_column character varying(30),
    is_view integer DEFAULT 0 NOT NULL,
    view_on_table_id bigint,
    superclass_table_id bigint,
    is_updateable integer DEFAULT 1 NOT NULL,
    modification_date date DEFAULT now() NOT NULL
);


ALTER TABLE chado.tableinfo OWNER TO www;

--
-- Name: tableinfo_tableinfo_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.tableinfo_tableinfo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.tableinfo_tableinfo_id_seq OWNER TO www;

--
-- Name: tableinfo_tableinfo_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.tableinfo_tableinfo_id_seq OWNED BY chado.tableinfo.tableinfo_id;


--
-- Name: tmp; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tmp (
    temp_id integer NOT NULL
);


ALTER TABLE chado.tmp OWNER TO www;

--
-- Name: tmp_cds_handler; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tmp_cds_handler (
    cds_row_id integer NOT NULL,
    seq_id character varying(1024),
    gff_id character varying(1024),
    type character varying(1024) NOT NULL,
    fmin integer NOT NULL,
    fmax integer NOT NULL,
    object text NOT NULL
);


ALTER TABLE chado.tmp_cds_handler OWNER TO www;

--
-- Name: tmp_cds_handler_cds_row_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.tmp_cds_handler_cds_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.tmp_cds_handler_cds_row_id_seq OWNER TO www;

--
-- Name: tmp_cds_handler_cds_row_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.tmp_cds_handler_cds_row_id_seq OWNED BY chado.tmp_cds_handler.cds_row_id;


--
-- Name: tmp_cds_handler_relationship; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tmp_cds_handler_relationship (
    rel_row_id integer NOT NULL,
    cds_row_id integer,
    parent_id character varying(1024),
    grandparent_id character varying(1024)
);


ALTER TABLE chado.tmp_cds_handler_relationship OWNER TO www;

--
-- Name: tmp_cds_handler_relationship_rel_row_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.tmp_cds_handler_relationship_rel_row_id_seq OWNER TO www;

--
-- Name: tmp_cds_handler_relationship_rel_row_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq OWNED BY chado.tmp_cds_handler_relationship.rel_row_id;


--
-- Name: tmp_temp_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.tmp_temp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.tmp_temp_id_seq OWNER TO www;

--
-- Name: tmp_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.tmp_temp_id_seq OWNED BY chado.tmp.temp_id;


--
-- Name: treatment; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.treatment (
    treatment_id bigint NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    biomaterial_id bigint NOT NULL,
    type_id bigint NOT NULL,
    protocol_id bigint,
    name text
);


ALTER TABLE chado.treatment OWNER TO www;

--
-- Name: TABLE treatment; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON TABLE chado.treatment IS 'A biomaterial may undergo multiple
treatments. Examples of treatments: apoxia, fluorophore and biotin labeling.';


--
-- Name: treatment_treatment_id_seq; Type: SEQUENCE; Schema: chado; Owner: www
--

CREATE SEQUENCE chado.treatment_treatment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chado.treatment_treatment_id_seq OWNER TO www;

--
-- Name: treatment_treatment_id_seq; Type: SEQUENCE OWNED BY; Schema: chado; Owner: www
--

ALTER SEQUENCE chado.treatment_treatment_id_seq OWNED BY chado.treatment.treatment_id;


--
-- Name: tripal_gff_temp; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tripal_gff_temp (
    feature_id integer NOT NULL,
    organism_id integer NOT NULL,
    uniquename text NOT NULL,
    type_name character varying(1024) NOT NULL
);


ALTER TABLE chado.tripal_gff_temp OWNER TO www;

--
-- Name: tripal_gffcds_temp; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tripal_gffcds_temp (
    feature_id integer NOT NULL,
    parent_id integer NOT NULL,
    phase integer,
    strand integer NOT NULL,
    fmin integer NOT NULL,
    fmax integer NOT NULL
);


ALTER TABLE chado.tripal_gffcds_temp OWNER TO www;

--
-- Name: tripal_gffprotein_temp; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tripal_gffprotein_temp (
    feature_id integer NOT NULL,
    parent_id integer NOT NULL,
    fmin integer NOT NULL,
    fmax integer NOT NULL
);


ALTER TABLE chado.tripal_gffprotein_temp OWNER TO www;

--
-- Name: tripal_obo_temp; Type: TABLE; Schema: chado; Owner: www
--

CREATE TABLE chado.tripal_obo_temp (
    id character varying(255) NOT NULL,
    stanza text NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE chado.tripal_obo_temp OWNER TO www;

--
-- Name: type_feature_count; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.type_feature_count AS
 SELECT t.name AS type,
    count(*) AS num_features
   FROM (chado.cvterm t
     JOIN chado.feature ON ((feature.type_id = t.cvterm_id)))
  GROUP BY t.name;


ALTER TABLE chado.type_feature_count OWNER TO www;

--
-- Name: VIEW type_feature_count; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON VIEW chado.type_feature_count IS 'per-feature-type feature counts';


--
-- Name: view_citation; Type: VIEW; Schema: chado; Owner: www
--

CREATE VIEW chado.view_citation AS
 SELECT p.pub_id,
    (((((((((((((pp.value || ' ('::text) || (p.pyear)::text) || ')'::text) || '. '::text) || p.title) || '. '::text) || (p.series_name)::text) || '. '::text) || (p.volume)::text) || ':'::text) || (p.issue)::text) || ' '::text) || (p.pages)::text) AS citation
   FROM (chado.pubprop pp
     JOIN chado.pub p ON ((p.pub_id = pp.pub_id)))
  WHERE ((pp.type_id = ( SELECT cvterm.cvterm_id
           FROM chado.cvterm
          WHERE ((cvterm.name)::text = 'Authors'::text))) AND (p.series_name IS NOT NULL));


ALTER TABLE chado.view_citation OWNER TO www;

--
-- Name: acquisition_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition ALTER COLUMN acquisition_id SET DEFAULT nextval('chado.acquisition_acquisition_id_seq'::regclass);


--
-- Name: acquisition_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship ALTER COLUMN acquisition_relationship_id SET DEFAULT nextval('chado.acquisition_relationship_acquisition_relationship_id_seq'::regclass);


--
-- Name: acquisitionprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisitionprop ALTER COLUMN acquisitionprop_id SET DEFAULT nextval('chado.acquisitionprop_acquisitionprop_id_seq'::regclass);


--
-- Name: analysis_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis ALTER COLUMN analysis_id SET DEFAULT nextval('chado.analysis_analysis_id_seq'::regclass);


--
-- Name: analysis_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_cvterm ALTER COLUMN analysis_cvterm_id SET DEFAULT nextval('chado.analysis_cvterm_analysis_cvterm_id_seq'::regclass);


--
-- Name: analysis_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_dbxref ALTER COLUMN analysis_dbxref_id SET DEFAULT nextval('chado.analysis_dbxref_analysis_dbxref_id_seq'::regclass);


--
-- Name: analysis_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_pub ALTER COLUMN analysis_pub_id SET DEFAULT nextval('chado.analysis_pub_analysis_pub_id_seq'::regclass);


--
-- Name: analysis_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship ALTER COLUMN analysis_relationship_id SET DEFAULT nextval('chado.analysis_relationship_analysis_relationship_id_seq'::regclass);


--
-- Name: analysisfeature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeature ALTER COLUMN analysisfeature_id SET DEFAULT nextval('chado.analysisfeature_analysisfeature_id_seq'::regclass);


--
-- Name: analysisfeatureprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeatureprop ALTER COLUMN analysisfeatureprop_id SET DEFAULT nextval('chado.analysisfeatureprop_analysisfeatureprop_id_seq'::regclass);


--
-- Name: analysisprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisprop ALTER COLUMN analysisprop_id SET DEFAULT nextval('chado.analysisprop_analysisprop_id_seq'::regclass);


--
-- Name: arraydesign_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign ALTER COLUMN arraydesign_id SET DEFAULT nextval('chado.arraydesign_arraydesign_id_seq'::regclass);


--
-- Name: arraydesignprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesignprop ALTER COLUMN arraydesignprop_id SET DEFAULT nextval('chado.arraydesignprop_arraydesignprop_id_seq'::regclass);


--
-- Name: assay_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay ALTER COLUMN assay_id SET DEFAULT nextval('chado.assay_assay_id_seq'::regclass);


--
-- Name: assay_biomaterial_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial ALTER COLUMN assay_biomaterial_id SET DEFAULT nextval('chado.assay_biomaterial_assay_biomaterial_id_seq'::regclass);


--
-- Name: assay_project_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_project ALTER COLUMN assay_project_id SET DEFAULT nextval('chado.assay_project_assay_project_id_seq'::regclass);


--
-- Name: assayprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assayprop ALTER COLUMN assayprop_id SET DEFAULT nextval('chado.assayprop_assayprop_id_seq'::regclass);


--
-- Name: biomaterial_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial ALTER COLUMN biomaterial_id SET DEFAULT nextval('chado.biomaterial_biomaterial_id_seq'::regclass);


--
-- Name: biomaterial_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_dbxref ALTER COLUMN biomaterial_dbxref_id SET DEFAULT nextval('chado.biomaterial_dbxref_biomaterial_dbxref_id_seq'::regclass);


--
-- Name: biomaterial_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship ALTER COLUMN biomaterial_relationship_id SET DEFAULT nextval('chado.biomaterial_relationship_biomaterial_relationship_id_seq'::regclass);


--
-- Name: biomaterial_treatment_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment ALTER COLUMN biomaterial_treatment_id SET DEFAULT nextval('chado.biomaterial_treatment_biomaterial_treatment_id_seq'::regclass);


--
-- Name: biomaterialprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterialprop ALTER COLUMN biomaterialprop_id SET DEFAULT nextval('chado.biomaterialprop_biomaterialprop_id_seq'::regclass);


--
-- Name: blast_org_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.blast_organisms ALTER COLUMN blast_org_id SET DEFAULT nextval('chado.blast_organisms_blast_org_id_seq'::regclass);


--
-- Name: cell_line_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line ALTER COLUMN cell_line_id SET DEFAULT nextval('chado.cell_line_cell_line_id_seq'::regclass);


--
-- Name: cell_line_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm ALTER COLUMN cell_line_cvterm_id SET DEFAULT nextval('chado.cell_line_cvterm_cell_line_cvterm_id_seq'::regclass);


--
-- Name: cell_line_cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvtermprop ALTER COLUMN cell_line_cvtermprop_id SET DEFAULT nextval('chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq'::regclass);


--
-- Name: cell_line_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_dbxref ALTER COLUMN cell_line_dbxref_id SET DEFAULT nextval('chado.cell_line_dbxref_cell_line_dbxref_id_seq'::regclass);


--
-- Name: cell_line_feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature ALTER COLUMN cell_line_feature_id SET DEFAULT nextval('chado.cell_line_feature_cell_line_feature_id_seq'::regclass);


--
-- Name: cell_line_library_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library ALTER COLUMN cell_line_library_id SET DEFAULT nextval('chado.cell_line_library_cell_line_library_id_seq'::regclass);


--
-- Name: cell_line_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_pub ALTER COLUMN cell_line_pub_id SET DEFAULT nextval('chado.cell_line_pub_cell_line_pub_id_seq'::regclass);


--
-- Name: cell_line_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship ALTER COLUMN cell_line_relationship_id SET DEFAULT nextval('chado.cell_line_relationship_cell_line_relationship_id_seq'::regclass);


--
-- Name: cell_line_synonym_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym ALTER COLUMN cell_line_synonym_id SET DEFAULT nextval('chado.cell_line_synonym_cell_line_synonym_id_seq'::regclass);


--
-- Name: cell_lineprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop ALTER COLUMN cell_lineprop_id SET DEFAULT nextval('chado.cell_lineprop_cell_lineprop_id_seq'::regclass);


--
-- Name: cell_lineprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop_pub ALTER COLUMN cell_lineprop_pub_id SET DEFAULT nextval('chado.cell_lineprop_pub_cell_lineprop_pub_id_seq'::regclass);


--
-- Name: chadoprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chadoprop ALTER COLUMN chadoprop_id SET DEFAULT nextval('chado.chadoprop_chadoprop_id_seq'::regclass);


--
-- Name: channel_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.channel ALTER COLUMN channel_id SET DEFAULT nextval('chado.channel_channel_id_seq'::regclass);


--
-- Name: contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact ALTER COLUMN contact_id SET DEFAULT nextval('chado.contact_contact_id_seq'::regclass);


--
-- Name: contact_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship ALTER COLUMN contact_relationship_id SET DEFAULT nextval('chado.contact_relationship_contact_relationship_id_seq'::regclass);


--
-- Name: contactprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop ALTER COLUMN contactprop_id SET DEFAULT nextval('chado.contactprop_contactprop_id_seq'::regclass);


--
-- Name: control_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.control ALTER COLUMN control_id SET DEFAULT nextval('chado.control_control_id_seq'::regclass);


--
-- Name: cv_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cv ALTER COLUMN cv_id SET DEFAULT nextval('chado.cv_cv_id_seq'::regclass);


--
-- Name: cvprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvprop ALTER COLUMN cvprop_id SET DEFAULT nextval('chado.cvprop_cvprop_id_seq'::regclass);


--
-- Name: cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm ALTER COLUMN cvterm_id SET DEFAULT nextval('chado.cvterm_cvterm_id_seq'::regclass);


--
-- Name: cvterm_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_dbxref ALTER COLUMN cvterm_dbxref_id SET DEFAULT nextval('chado.cvterm_dbxref_cvterm_dbxref_id_seq'::regclass);


--
-- Name: cvterm_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship ALTER COLUMN cvterm_relationship_id SET DEFAULT nextval('chado.cvterm_relationship_cvterm_relationship_id_seq'::regclass);


--
-- Name: cvtermpath_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath ALTER COLUMN cvtermpath_id SET DEFAULT nextval('chado.cvtermpath_cvtermpath_id_seq'::regclass);


--
-- Name: cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermprop ALTER COLUMN cvtermprop_id SET DEFAULT nextval('chado.cvtermprop_cvtermprop_id_seq'::regclass);


--
-- Name: cvtermsynonym_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermsynonym ALTER COLUMN cvtermsynonym_id SET DEFAULT nextval('chado.cvtermsynonym_cvtermsynonym_id_seq'::regclass);


--
-- Name: db_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.db ALTER COLUMN db_id SET DEFAULT nextval('chado.db_db_id_seq'::regclass);


--
-- Name: dbprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbprop ALTER COLUMN dbprop_id SET DEFAULT nextval('chado.dbprop_dbprop_id_seq'::regclass);


--
-- Name: dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxref ALTER COLUMN dbxref_id SET DEFAULT nextval('chado.dbxref_dbxref_id_seq'::regclass);


--
-- Name: dbxrefprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxrefprop ALTER COLUMN dbxrefprop_id SET DEFAULT nextval('chado.dbxrefprop_dbxrefprop_id_seq'::regclass);


--
-- Name: eimage_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.eimage ALTER COLUMN eimage_id SET DEFAULT nextval('chado.eimage_eimage_id_seq'::regclass);


--
-- Name: element_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element ALTER COLUMN element_id SET DEFAULT nextval('chado.element_element_id_seq'::regclass);


--
-- Name: element_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship ALTER COLUMN element_relationship_id SET DEFAULT nextval('chado.element_relationship_element_relationship_id_seq'::regclass);


--
-- Name: elementresult_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult ALTER COLUMN elementresult_id SET DEFAULT nextval('chado.elementresult_elementresult_id_seq'::regclass);


--
-- Name: elementresult_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship ALTER COLUMN elementresult_relationship_id SET DEFAULT nextval('chado.elementresult_relationship_elementresult_relationship_id_seq'::regclass);


--
-- Name: environment_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment ALTER COLUMN environment_id SET DEFAULT nextval('chado.environment_environment_id_seq'::regclass);


--
-- Name: environment_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment_cvterm ALTER COLUMN environment_cvterm_id SET DEFAULT nextval('chado.environment_cvterm_environment_cvterm_id_seq'::regclass);


--
-- Name: expression_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression ALTER COLUMN expression_id SET DEFAULT nextval('chado.expression_expression_id_seq'::regclass);


--
-- Name: expression_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm ALTER COLUMN expression_cvterm_id SET DEFAULT nextval('chado.expression_cvterm_expression_cvterm_id_seq'::regclass);


--
-- Name: expression_cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvtermprop ALTER COLUMN expression_cvtermprop_id SET DEFAULT nextval('chado.expression_cvtermprop_expression_cvtermprop_id_seq'::regclass);


--
-- Name: expression_image_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_image ALTER COLUMN expression_image_id SET DEFAULT nextval('chado.expression_image_expression_image_id_seq'::regclass);


--
-- Name: expression_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_pub ALTER COLUMN expression_pub_id SET DEFAULT nextval('chado.expression_pub_expression_pub_id_seq'::regclass);


--
-- Name: expressionprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expressionprop ALTER COLUMN expressionprop_id SET DEFAULT nextval('chado.expressionprop_expressionprop_id_seq'::regclass);


--
-- Name: feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature ALTER COLUMN feature_id SET DEFAULT nextval('chado.feature_feature_id_seq'::regclass);


--
-- Name: feature_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_contact ALTER COLUMN feature_contact_id SET DEFAULT nextval('chado.feature_contact_feature_contact_id_seq'::regclass);


--
-- Name: feature_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm ALTER COLUMN feature_cvterm_id SET DEFAULT nextval('chado.feature_cvterm_feature_cvterm_id_seq'::regclass);


--
-- Name: feature_cvterm_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_dbxref ALTER COLUMN feature_cvterm_dbxref_id SET DEFAULT nextval('chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq'::regclass);


--
-- Name: feature_cvterm_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_pub ALTER COLUMN feature_cvterm_pub_id SET DEFAULT nextval('chado.feature_cvterm_pub_feature_cvterm_pub_id_seq'::regclass);


--
-- Name: feature_cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvtermprop ALTER COLUMN feature_cvtermprop_id SET DEFAULT nextval('chado.feature_cvtermprop_feature_cvtermprop_id_seq'::regclass);


--
-- Name: feature_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_dbxref ALTER COLUMN feature_dbxref_id SET DEFAULT nextval('chado.feature_dbxref_feature_dbxref_id_seq'::regclass);


--
-- Name: feature_expression_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression ALTER COLUMN feature_expression_id SET DEFAULT nextval('chado.feature_expression_feature_expression_id_seq'::regclass);


--
-- Name: feature_expressionprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expressionprop ALTER COLUMN feature_expressionprop_id SET DEFAULT nextval('chado.feature_expressionprop_feature_expressionprop_id_seq'::regclass);


--
-- Name: feature_genotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype ALTER COLUMN feature_genotype_id SET DEFAULT nextval('chado.feature_genotype_feature_genotype_id_seq'::regclass);


--
-- Name: feature_phenotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_phenotype ALTER COLUMN feature_phenotype_id SET DEFAULT nextval('chado.feature_phenotype_feature_phenotype_id_seq'::regclass);


--
-- Name: feature_project_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_project ALTER COLUMN feature_project_id SET DEFAULT nextval('chado.feature_project_feature_project_id_seq'::regclass);


--
-- Name: feature_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pub ALTER COLUMN feature_pub_id SET DEFAULT nextval('chado.feature_pub_feature_pub_id_seq'::regclass);


--
-- Name: feature_pubprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pubprop ALTER COLUMN feature_pubprop_id SET DEFAULT nextval('chado.feature_pubprop_feature_pubprop_id_seq'::regclass);


--
-- Name: feature_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship ALTER COLUMN feature_relationship_id SET DEFAULT nextval('chado.feature_relationship_feature_relationship_id_seq'::regclass);


--
-- Name: feature_relationship_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship_pub ALTER COLUMN feature_relationship_pub_id SET DEFAULT nextval('chado.feature_relationship_pub_feature_relationship_pub_id_seq'::regclass);


--
-- Name: feature_relationshipprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop ALTER COLUMN feature_relationshipprop_id SET DEFAULT nextval('chado.feature_relationshipprop_feature_relationshipprop_id_seq'::regclass);


--
-- Name: feature_relationshipprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop_pub ALTER COLUMN feature_relationshipprop_pub_id SET DEFAULT nextval('chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq'::regclass);


--
-- Name: feature_stock_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock ALTER COLUMN feature_stock_id SET DEFAULT nextval('chado.feature_stock_feature_stock_id_seq'::regclass);


--
-- Name: feature_synonym_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym ALTER COLUMN feature_synonym_id SET DEFAULT nextval('chado.feature_synonym_feature_synonym_id_seq'::regclass);


--
-- Name: featureloc_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc ALTER COLUMN featureloc_id SET DEFAULT nextval('chado.featureloc_featureloc_id_seq'::regclass);


--
-- Name: featureloc_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc_pub ALTER COLUMN featureloc_pub_id SET DEFAULT nextval('chado.featureloc_pub_featureloc_pub_id_seq'::regclass);


--
-- Name: featurelocprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurelocprop ALTER COLUMN featurelocprop_id SET DEFAULT nextval('chado.featurelocprop_featurelocprop_id_seq'::regclass);


--
-- Name: featuremap_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap ALTER COLUMN featuremap_id SET DEFAULT nextval('chado.featuremap_featuremap_id_seq'::regclass);


--
-- Name: featuremap_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_contact ALTER COLUMN featuremap_contact_id SET DEFAULT nextval('chado.featuremap_contact_featuremap_contact_id_seq'::regclass);


--
-- Name: featuremap_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_dbxref ALTER COLUMN featuremap_dbxref_id SET DEFAULT nextval('chado.featuremap_dbxref_featuremap_dbxref_id_seq'::regclass);


--
-- Name: featuremap_organism_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_organism ALTER COLUMN featuremap_organism_id SET DEFAULT nextval('chado.featuremap_organism_featuremap_organism_id_seq'::regclass);


--
-- Name: featuremap_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_pub ALTER COLUMN featuremap_pub_id SET DEFAULT nextval('chado.featuremap_pub_featuremap_pub_id_seq'::regclass);


--
-- Name: featuremap_stock_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_stock ALTER COLUMN featuremap_stock_id SET DEFAULT nextval('chado.featuremap_stock_featuremap_stock_id_seq'::regclass);


--
-- Name: featuremapprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop ALTER COLUMN featuremapprop_id SET DEFAULT nextval('chado.featuremapprop_featuremapprop_id_seq'::regclass);


--
-- Name: featurepos_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurepos ALTER COLUMN featurepos_id SET DEFAULT nextval('chado.featurepos_featurepos_id_seq'::regclass);


--
-- Name: featureposprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop ALTER COLUMN featureposprop_id SET DEFAULT nextval('chado.featureposprop_featureposprop_id_seq'::regclass);


--
-- Name: featureprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop ALTER COLUMN featureprop_id SET DEFAULT nextval('chado.featureprop_featureprop_id_seq'::regclass);


--
-- Name: featureprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop_pub ALTER COLUMN featureprop_pub_id SET DEFAULT nextval('chado.featureprop_pub_featureprop_pub_id_seq'::regclass);


--
-- Name: featurerange_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange ALTER COLUMN featurerange_id SET DEFAULT nextval('chado.featurerange_featurerange_id_seq'::regclass);


--
-- Name: genotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotype ALTER COLUMN genotype_id SET DEFAULT nextval('chado.genotype_genotype_id_seq'::regclass);


--
-- Name: genotypeprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotypeprop ALTER COLUMN genotypeprop_id SET DEFAULT nextval('chado.genotypeprop_genotypeprop_id_seq'::regclass);


--
-- Name: library_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library ALTER COLUMN library_id SET DEFAULT nextval('chado.library_library_id_seq'::regclass);


--
-- Name: library_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_contact ALTER COLUMN library_contact_id SET DEFAULT nextval('chado.library_contact_library_contact_id_seq'::regclass);


--
-- Name: library_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm ALTER COLUMN library_cvterm_id SET DEFAULT nextval('chado.library_cvterm_library_cvterm_id_seq'::regclass);


--
-- Name: library_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_dbxref ALTER COLUMN library_dbxref_id SET DEFAULT nextval('chado.library_dbxref_library_dbxref_id_seq'::regclass);


--
-- Name: library_expression_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression ALTER COLUMN library_expression_id SET DEFAULT nextval('chado.library_expression_library_expression_id_seq'::regclass);


--
-- Name: library_expressionprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expressionprop ALTER COLUMN library_expressionprop_id SET DEFAULT nextval('chado.library_expressionprop_library_expressionprop_id_seq'::regclass);


--
-- Name: library_feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_feature ALTER COLUMN library_feature_id SET DEFAULT nextval('chado.library_feature_library_feature_id_seq'::regclass);


--
-- Name: library_featureprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_featureprop ALTER COLUMN library_featureprop_id SET DEFAULT nextval('chado.library_featureprop_library_featureprop_id_seq'::regclass);


--
-- Name: library_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_pub ALTER COLUMN library_pub_id SET DEFAULT nextval('chado.library_pub_library_pub_id_seq'::regclass);


--
-- Name: library_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship ALTER COLUMN library_relationship_id SET DEFAULT nextval('chado.library_relationship_library_relationship_id_seq'::regclass);


--
-- Name: library_relationship_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship_pub ALTER COLUMN library_relationship_pub_id SET DEFAULT nextval('chado.library_relationship_pub_library_relationship_pub_id_seq'::regclass);


--
-- Name: library_synonym_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym ALTER COLUMN library_synonym_id SET DEFAULT nextval('chado.library_synonym_library_synonym_id_seq'::regclass);


--
-- Name: libraryprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop ALTER COLUMN libraryprop_id SET DEFAULT nextval('chado.libraryprop_libraryprop_id_seq'::regclass);


--
-- Name: libraryprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop_pub ALTER COLUMN libraryprop_pub_id SET DEFAULT nextval('chado.libraryprop_pub_libraryprop_pub_id_seq'::regclass);


--
-- Name: oid; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.lightshop_order ALTER COLUMN oid SET DEFAULT nextval('chado.lightshop_order_oid_seq'::regclass);


--
-- Name: magedocumentation_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.magedocumentation ALTER COLUMN magedocumentation_id SET DEFAULT nextval('chado.magedocumentation_magedocumentation_id_seq'::regclass);


--
-- Name: mageml_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.mageml ALTER COLUMN mageml_id SET DEFAULT nextval('chado.mageml_mageml_id_seq'::regclass);


--
-- Name: materialized_view_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.materialized_view ALTER COLUMN materialized_view_id SET DEFAULT nextval('chado.materialized_view_materialized_view_id_seq'::regclass);


--
-- Name: nd_experiment_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment ALTER COLUMN nd_experiment_id SET DEFAULT nextval('chado.nd_experiment_nd_experiment_id_seq'::regclass);


--
-- Name: nd_experiment_analysis_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_analysis ALTER COLUMN nd_experiment_analysis_id SET DEFAULT nextval('chado.nd_experiment_analysis_nd_experiment_analysis_id_seq'::regclass);


--
-- Name: nd_experiment_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_contact ALTER COLUMN nd_experiment_contact_id SET DEFAULT nextval('chado.nd_experiment_contact_nd_experiment_contact_id_seq'::regclass);


--
-- Name: nd_experiment_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_dbxref ALTER COLUMN nd_experiment_dbxref_id SET DEFAULT nextval('chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq'::regclass);


--
-- Name: nd_experiment_genotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_genotype ALTER COLUMN nd_experiment_genotype_id SET DEFAULT nextval('chado.nd_experiment_genotype_nd_experiment_genotype_id_seq'::regclass);


--
-- Name: nd_experiment_phenotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_phenotype ALTER COLUMN nd_experiment_phenotype_id SET DEFAULT nextval('chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq'::regclass);


--
-- Name: nd_experiment_project_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_project ALTER COLUMN nd_experiment_project_id SET DEFAULT nextval('chado.nd_experiment_project_nd_experiment_project_id_seq'::regclass);


--
-- Name: nd_experiment_protocol_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_protocol ALTER COLUMN nd_experiment_protocol_id SET DEFAULT nextval('chado.nd_experiment_protocol_nd_experiment_protocol_id_seq'::regclass);


--
-- Name: nd_experiment_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_pub ALTER COLUMN nd_experiment_pub_id SET DEFAULT nextval('chado.nd_experiment_pub_nd_experiment_pub_id_seq'::regclass);


--
-- Name: nd_experiment_stock_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock ALTER COLUMN nd_experiment_stock_id SET DEFAULT nextval('chado.nd_experiment_stock_nd_experiment_stock_id_seq'::regclass);


--
-- Name: nd_experiment_stock_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock_dbxref ALTER COLUMN nd_experiment_stock_dbxref_id SET DEFAULT nextval('chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq'::regclass);


--
-- Name: nd_experiment_stockprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stockprop ALTER COLUMN nd_experiment_stockprop_id SET DEFAULT nextval('chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq'::regclass);


--
-- Name: nd_experimentprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experimentprop ALTER COLUMN nd_experimentprop_id SET DEFAULT nextval('chado.nd_experimentprop_nd_experimentprop_id_seq'::regclass);


--
-- Name: nd_geolocation_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocation ALTER COLUMN nd_geolocation_id SET DEFAULT nextval('chado.nd_geolocation_nd_geolocation_id_seq'::regclass);


--
-- Name: nd_geolocationprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocationprop ALTER COLUMN nd_geolocationprop_id SET DEFAULT nextval('chado.nd_geolocationprop_nd_geolocationprop_id_seq'::regclass);


--
-- Name: nd_protocol_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol ALTER COLUMN nd_protocol_id SET DEFAULT nextval('chado.nd_protocol_nd_protocol_id_seq'::regclass);


--
-- Name: nd_protocol_reagent_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol_reagent ALTER COLUMN nd_protocol_reagent_id SET DEFAULT nextval('chado.nd_protocol_reagent_nd_protocol_reagent_id_seq'::regclass);


--
-- Name: nd_protocolprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocolprop ALTER COLUMN nd_protocolprop_id SET DEFAULT nextval('chado.nd_protocolprop_nd_protocolprop_id_seq'::regclass);


--
-- Name: nd_reagent_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent ALTER COLUMN nd_reagent_id SET DEFAULT nextval('chado.nd_reagent_nd_reagent_id_seq'::regclass);


--
-- Name: nd_reagent_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent_relationship ALTER COLUMN nd_reagent_relationship_id SET DEFAULT nextval('chado.nd_reagent_relationship_nd_reagent_relationship_id_seq'::regclass);


--
-- Name: nd_reagentprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagentprop ALTER COLUMN nd_reagentprop_id SET DEFAULT nextval('chado.nd_reagentprop_nd_reagentprop_id_seq'::regclass);


--
-- Name: organism_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism ALTER COLUMN organism_id SET DEFAULT nextval('chado.organism_organism_id_seq'::regclass);


--
-- Name: organism_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm ALTER COLUMN organism_cvterm_id SET DEFAULT nextval('chado.organism_cvterm_organism_cvterm_id_seq'::regclass);


--
-- Name: organism_cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvtermprop ALTER COLUMN organism_cvtermprop_id SET DEFAULT nextval('chado.organism_cvtermprop_organism_cvtermprop_id_seq'::regclass);


--
-- Name: organism_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_dbxref ALTER COLUMN organism_dbxref_id SET DEFAULT nextval('chado.organism_dbxref_organism_dbxref_id_seq'::regclass);


--
-- Name: organism_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_pub ALTER COLUMN organism_pub_id SET DEFAULT nextval('chado.organism_pub_organism_pub_id_seq'::regclass);


--
-- Name: organism_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship ALTER COLUMN organism_relationship_id SET DEFAULT nextval('chado.organism_relationship_organism_relationship_id_seq'::regclass);


--
-- Name: organismprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop ALTER COLUMN organismprop_id SET DEFAULT nextval('chado.organismprop_organismprop_id_seq'::regclass);


--
-- Name: organismprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop_pub ALTER COLUMN organismprop_pub_id SET DEFAULT nextval('chado.organismprop_pub_organismprop_pub_id_seq'::regclass);


--
-- Name: phendesc_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc ALTER COLUMN phendesc_id SET DEFAULT nextval('chado.phendesc_phendesc_id_seq'::regclass);


--
-- Name: phenotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype ALTER COLUMN phenotype_id SET DEFAULT nextval('chado.phenotype_phenotype_id_seq'::regclass);


--
-- Name: phenotype_comparison_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison ALTER COLUMN phenotype_comparison_id SET DEFAULT nextval('chado.phenotype_comparison_phenotype_comparison_id_seq'::regclass);


--
-- Name: phenotype_comparison_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm ALTER COLUMN phenotype_comparison_cvterm_id SET DEFAULT nextval('chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq'::regclass);


--
-- Name: phenotype_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_cvterm ALTER COLUMN phenotype_cvterm_id SET DEFAULT nextval('chado.phenotype_cvterm_phenotype_cvterm_id_seq'::regclass);


--
-- Name: phenotypeprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotypeprop ALTER COLUMN phenotypeprop_id SET DEFAULT nextval('chado.phenotypeprop_phenotypeprop_id_seq'::regclass);


--
-- Name: phenstatement_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement ALTER COLUMN phenstatement_id SET DEFAULT nextval('chado.phenstatement_phenstatement_id_seq'::regclass);


--
-- Name: phylonode_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode ALTER COLUMN phylonode_id SET DEFAULT nextval('chado.phylonode_phylonode_id_seq'::regclass);


--
-- Name: phylonode_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_dbxref ALTER COLUMN phylonode_dbxref_id SET DEFAULT nextval('chado.phylonode_dbxref_phylonode_dbxref_id_seq'::regclass);


--
-- Name: phylonode_organism_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_organism ALTER COLUMN phylonode_organism_id SET DEFAULT nextval('chado.phylonode_organism_phylonode_organism_id_seq'::regclass);


--
-- Name: phylonode_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_pub ALTER COLUMN phylonode_pub_id SET DEFAULT nextval('chado.phylonode_pub_phylonode_pub_id_seq'::regclass);


--
-- Name: phylonode_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship ALTER COLUMN phylonode_relationship_id SET DEFAULT nextval('chado.phylonode_relationship_phylonode_relationship_id_seq'::regclass);


--
-- Name: phylonodeprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonodeprop ALTER COLUMN phylonodeprop_id SET DEFAULT nextval('chado.phylonodeprop_phylonodeprop_id_seq'::regclass);


--
-- Name: phylotree_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree ALTER COLUMN phylotree_id SET DEFAULT nextval('chado.phylotree_phylotree_id_seq'::regclass);


--
-- Name: phylotree_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree_pub ALTER COLUMN phylotree_pub_id SET DEFAULT nextval('chado.phylotree_pub_phylotree_pub_id_seq'::regclass);


--
-- Name: phylotreeprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotreeprop ALTER COLUMN phylotreeprop_id SET DEFAULT nextval('chado.phylotreeprop_phylotreeprop_id_seq'::regclass);


--
-- Name: project_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project ALTER COLUMN project_id SET DEFAULT nextval('chado.project_project_id_seq'::regclass);


--
-- Name: project_analysis_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_analysis ALTER COLUMN project_analysis_id SET DEFAULT nextval('chado.project_analysis_project_analysis_id_seq'::regclass);


--
-- Name: project_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_contact ALTER COLUMN project_contact_id SET DEFAULT nextval('chado.project_contact_project_contact_id_seq'::regclass);


--
-- Name: project_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_dbxref ALTER COLUMN project_dbxref_id SET DEFAULT nextval('chado.project_dbxref_project_dbxref_id_seq'::regclass);


--
-- Name: project_feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_feature ALTER COLUMN project_feature_id SET DEFAULT nextval('chado.project_feature_project_feature_id_seq'::regclass);


--
-- Name: project_phenotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_phenotype ALTER COLUMN project_phenotype_id SET DEFAULT nextval('chado.project_phenotype_project_phenotype_id_seq'::regclass);


--
-- Name: project_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_pub ALTER COLUMN project_pub_id SET DEFAULT nextval('chado.project_pub_project_pub_id_seq'::regclass);


--
-- Name: project_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship ALTER COLUMN project_relationship_id SET DEFAULT nextval('chado.project_relationship_project_relationship_id_seq'::regclass);


--
-- Name: projectprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.projectprop ALTER COLUMN projectprop_id SET DEFAULT nextval('chado.projectprop_projectprop_id_seq'::regclass);


--
-- Name: protocol_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol ALTER COLUMN protocol_id SET DEFAULT nextval('chado.protocol_protocol_id_seq'::regclass);


--
-- Name: protocolparam_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocolparam ALTER COLUMN protocolparam_id SET DEFAULT nextval('chado.protocolparam_protocolparam_id_seq'::regclass);


--
-- Name: pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub ALTER COLUMN pub_id SET DEFAULT nextval('chado.pub_pub_id_seq'::regclass);


--
-- Name: pub_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_dbxref ALTER COLUMN pub_dbxref_id SET DEFAULT nextval('chado.pub_dbxref_pub_dbxref_id_seq'::regclass);


--
-- Name: pub_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship ALTER COLUMN pub_relationship_id SET DEFAULT nextval('chado.pub_relationship_pub_relationship_id_seq'::regclass);


--
-- Name: pubauthor_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor ALTER COLUMN pubauthor_id SET DEFAULT nextval('chado.pubauthor_pubauthor_id_seq'::regclass);


--
-- Name: pubauthor_contact_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor_contact ALTER COLUMN pubauthor_contact_id SET DEFAULT nextval('chado.pubauthor_contact_pubauthor_contact_id_seq'::regclass);


--
-- Name: pubprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubprop ALTER COLUMN pubprop_id SET DEFAULT nextval('chado.pubprop_pubprop_id_seq'::regclass);


--
-- Name: quantification_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification ALTER COLUMN quantification_id SET DEFAULT nextval('chado.quantification_quantification_id_seq'::regclass);


--
-- Name: quantification_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship ALTER COLUMN quantification_relationship_id SET DEFAULT nextval('chado.quantification_relationship_quantification_relationship_id_seq'::regclass);


--
-- Name: quantificationprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantificationprop ALTER COLUMN quantificationprop_id SET DEFAULT nextval('chado.quantificationprop_quantificationprop_id_seq'::regclass);


--
-- Name: stock_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock ALTER COLUMN stock_id SET DEFAULT nextval('chado.stock_stock_id_seq'::regclass);


--
-- Name: stock_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm ALTER COLUMN stock_cvterm_id SET DEFAULT nextval('chado.stock_cvterm_stock_cvterm_id_seq'::regclass);


--
-- Name: stock_cvtermprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvtermprop ALTER COLUMN stock_cvtermprop_id SET DEFAULT nextval('chado.stock_cvtermprop_stock_cvtermprop_id_seq'::regclass);


--
-- Name: stock_dbxref_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxref ALTER COLUMN stock_dbxref_id SET DEFAULT nextval('chado.stock_dbxref_stock_dbxref_id_seq'::regclass);


--
-- Name: stock_dbxrefprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxrefprop ALTER COLUMN stock_dbxrefprop_id SET DEFAULT nextval('chado.stock_dbxrefprop_stock_dbxrefprop_id_seq'::regclass);


--
-- Name: stock_eimage_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_eimage ALTER COLUMN stock_eimage_id SET DEFAULT nextval('chado.stock_eimage_stock_eimage_id_seq'::regclass);


--
-- Name: stock_feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature ALTER COLUMN stock_feature_id SET DEFAULT nextval('chado.stock_feature_stock_feature_id_seq'::regclass);


--
-- Name: stock_genotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_genotype ALTER COLUMN stock_genotype_id SET DEFAULT nextval('chado.stock_genotype_stock_genotype_id_seq'::regclass);


--
-- Name: stock_organism_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_organism ALTER COLUMN stock_organism_id SET DEFAULT nextval('chado.stock_organism_stock_organism_id_seq'::regclass);


--
-- Name: stock_phenotype_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_phenotype ALTER COLUMN stock_phenotype_id SET DEFAULT nextval('chado.stock_phenotype_stock_phenotype_id_seq'::regclass);


--
-- Name: stock_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_pub ALTER COLUMN stock_pub_id SET DEFAULT nextval('chado.stock_pub_stock_pub_id_seq'::regclass);


--
-- Name: stock_relationship_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship ALTER COLUMN stock_relationship_id SET DEFAULT nextval('chado.stock_relationship_stock_relationship_id_seq'::regclass);


--
-- Name: stock_relationship_cvterm_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_cvterm ALTER COLUMN stock_relationship_cvterm_id SET DEFAULT nextval('chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq'::regclass);


--
-- Name: stock_relationship_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_pub ALTER COLUMN stock_relationship_pub_id SET DEFAULT nextval('chado.stock_relationship_pub_stock_relationship_pub_id_seq'::regclass);


--
-- Name: stockcollection_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection ALTER COLUMN stockcollection_id SET DEFAULT nextval('chado.stockcollection_stockcollection_id_seq'::regclass);


--
-- Name: stockcollection_stock_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_stock ALTER COLUMN stockcollection_stock_id SET DEFAULT nextval('chado.stockcollection_stock_stockcollection_stock_id_seq'::regclass);


--
-- Name: stockcollectionprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollectionprop ALTER COLUMN stockcollectionprop_id SET DEFAULT nextval('chado.stockcollectionprop_stockcollectionprop_id_seq'::regclass);


--
-- Name: stockprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop ALTER COLUMN stockprop_id SET DEFAULT nextval('chado.stockprop_stockprop_id_seq'::regclass);


--
-- Name: stockprop_pub_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop_pub ALTER COLUMN stockprop_pub_id SET DEFAULT nextval('chado.stockprop_pub_stockprop_pub_id_seq'::regclass);


--
-- Name: study_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study ALTER COLUMN study_id SET DEFAULT nextval('chado.study_study_id_seq'::regclass);


--
-- Name: study_assay_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study_assay ALTER COLUMN study_assay_id SET DEFAULT nextval('chado.study_assay_study_assay_id_seq'::regclass);


--
-- Name: studydesign_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesign ALTER COLUMN studydesign_id SET DEFAULT nextval('chado.studydesign_studydesign_id_seq'::regclass);


--
-- Name: studydesignprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesignprop ALTER COLUMN studydesignprop_id SET DEFAULT nextval('chado.studydesignprop_studydesignprop_id_seq'::regclass);


--
-- Name: studyfactor_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactor ALTER COLUMN studyfactor_id SET DEFAULT nextval('chado.studyfactor_studyfactor_id_seq'::regclass);


--
-- Name: studyfactorvalue_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactorvalue ALTER COLUMN studyfactorvalue_id SET DEFAULT nextval('chado.studyfactorvalue_studyfactorvalue_id_seq'::regclass);


--
-- Name: studyprop_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop ALTER COLUMN studyprop_id SET DEFAULT nextval('chado.studyprop_studyprop_id_seq'::regclass);


--
-- Name: studyprop_feature_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature ALTER COLUMN studyprop_feature_id SET DEFAULT nextval('chado.studyprop_feature_studyprop_feature_id_seq'::regclass);


--
-- Name: synonym_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.synonym ALTER COLUMN synonym_id SET DEFAULT nextval('chado.synonym_synonym_id_seq'::regclass);


--
-- Name: tableinfo_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tableinfo ALTER COLUMN tableinfo_id SET DEFAULT nextval('chado.tableinfo_tableinfo_id_seq'::regclass);


--
-- Name: temp_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp ALTER COLUMN temp_id SET DEFAULT nextval('chado.tmp_temp_id_seq'::regclass);


--
-- Name: cds_row_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp_cds_handler ALTER COLUMN cds_row_id SET DEFAULT nextval('chado.tmp_cds_handler_cds_row_id_seq'::regclass);


--
-- Name: rel_row_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp_cds_handler_relationship ALTER COLUMN rel_row_id SET DEFAULT nextval('chado.tmp_cds_handler_relationship_rel_row_id_seq'::regclass);


--
-- Name: treatment_id; Type: DEFAULT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.treatment ALTER COLUMN treatment_id SET DEFAULT nextval('chado.treatment_treatment_id_seq'::regclass);


--
-- Name: acquisition_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition
    ADD CONSTRAINT acquisition_c1 UNIQUE (name);


--
-- Name: acquisition_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition
    ADD CONSTRAINT acquisition_pkey PRIMARY KEY (acquisition_id);


--
-- Name: acquisition_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship
    ADD CONSTRAINT acquisition_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: acquisition_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship
    ADD CONSTRAINT acquisition_relationship_pkey PRIMARY KEY (acquisition_relationship_id);


--
-- Name: acquisitionprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisitionprop
    ADD CONSTRAINT acquisitionprop_c1 UNIQUE (acquisition_id, type_id, rank);


--
-- Name: acquisitionprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisitionprop
    ADD CONSTRAINT acquisitionprop_pkey PRIMARY KEY (acquisitionprop_id);


--
-- Name: analysis_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis
    ADD CONSTRAINT analysis_c1 UNIQUE (program, programversion, sourcename);


--
-- Name: analysis_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_cvterm
    ADD CONSTRAINT analysis_cvterm_c1 UNIQUE (analysis_id, cvterm_id, rank);


--
-- Name: analysis_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_cvterm
    ADD CONSTRAINT analysis_cvterm_pkey PRIMARY KEY (analysis_cvterm_id);


--
-- Name: analysis_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_dbxref
    ADD CONSTRAINT analysis_dbxref_c1 UNIQUE (analysis_id, dbxref_id);


--
-- Name: analysis_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_dbxref
    ADD CONSTRAINT analysis_dbxref_pkey PRIMARY KEY (analysis_dbxref_id);


--
-- Name: analysis_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis
    ADD CONSTRAINT analysis_pkey PRIMARY KEY (analysis_id);


--
-- Name: analysis_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_pub
    ADD CONSTRAINT analysis_pub_c1 UNIQUE (analysis_id, pub_id);


--
-- Name: analysis_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_pub
    ADD CONSTRAINT analysis_pub_pkey PRIMARY KEY (analysis_pub_id);


--
-- Name: analysis_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship
    ADD CONSTRAINT analysis_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: analysis_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship
    ADD CONSTRAINT analysis_relationship_pkey PRIMARY KEY (analysis_relationship_id);


--
-- Name: analysisfeature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeature
    ADD CONSTRAINT analysisfeature_c1 UNIQUE (feature_id, analysis_id);


--
-- Name: analysisfeature_id_type_id_rank; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeatureprop
    ADD CONSTRAINT analysisfeature_id_type_id_rank UNIQUE (analysisfeature_id, type_id, rank);


--
-- Name: analysisfeature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeature
    ADD CONSTRAINT analysisfeature_pkey PRIMARY KEY (analysisfeature_id);


--
-- Name: analysisfeatureprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeatureprop
    ADD CONSTRAINT analysisfeatureprop_pkey PRIMARY KEY (analysisfeatureprop_id);


--
-- Name: analysisprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisprop
    ADD CONSTRAINT analysisprop_c1 UNIQUE (analysis_id, type_id, rank);


--
-- Name: analysisprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisprop
    ADD CONSTRAINT analysisprop_pkey PRIMARY KEY (analysisprop_id);


--
-- Name: arraydesign_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_c1 UNIQUE (name);


--
-- Name: arraydesign_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_pkey PRIMARY KEY (arraydesign_id);


--
-- Name: arraydesignprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesignprop
    ADD CONSTRAINT arraydesignprop_c1 UNIQUE (arraydesign_id, type_id, rank);


--
-- Name: arraydesignprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesignprop
    ADD CONSTRAINT arraydesignprop_pkey PRIMARY KEY (arraydesignprop_id);


--
-- Name: assay_biomaterial_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial
    ADD CONSTRAINT assay_biomaterial_c1 UNIQUE (assay_id, biomaterial_id, channel_id, rank);


--
-- Name: assay_biomaterial_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial
    ADD CONSTRAINT assay_biomaterial_pkey PRIMARY KEY (assay_biomaterial_id);


--
-- Name: assay_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_c1 UNIQUE (name);


--
-- Name: assay_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_pkey PRIMARY KEY (assay_id);


--
-- Name: assay_project_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_project
    ADD CONSTRAINT assay_project_c1 UNIQUE (assay_id, project_id);


--
-- Name: assay_project_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_project
    ADD CONSTRAINT assay_project_pkey PRIMARY KEY (assay_project_id);


--
-- Name: assayprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assayprop
    ADD CONSTRAINT assayprop_c1 UNIQUE (assay_id, type_id, rank);


--
-- Name: assayprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assayprop
    ADD CONSTRAINT assayprop_pkey PRIMARY KEY (assayprop_id);


--
-- Name: biomaterial_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial
    ADD CONSTRAINT biomaterial_c1 UNIQUE (name);


--
-- Name: biomaterial_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_dbxref
    ADD CONSTRAINT biomaterial_dbxref_c1 UNIQUE (biomaterial_id, dbxref_id);


--
-- Name: biomaterial_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_dbxref
    ADD CONSTRAINT biomaterial_dbxref_pkey PRIMARY KEY (biomaterial_dbxref_id);


--
-- Name: biomaterial_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial
    ADD CONSTRAINT biomaterial_pkey PRIMARY KEY (biomaterial_id);


--
-- Name: biomaterial_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship
    ADD CONSTRAINT biomaterial_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: biomaterial_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship
    ADD CONSTRAINT biomaterial_relationship_pkey PRIMARY KEY (biomaterial_relationship_id);


--
-- Name: biomaterial_treatment_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment
    ADD CONSTRAINT biomaterial_treatment_c1 UNIQUE (biomaterial_id, treatment_id);


--
-- Name: biomaterial_treatment_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment
    ADD CONSTRAINT biomaterial_treatment_pkey PRIMARY KEY (biomaterial_treatment_id);


--
-- Name: biomaterialprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterialprop
    ADD CONSTRAINT biomaterialprop_c1 UNIQUE (biomaterial_id, type_id, rank);


--
-- Name: biomaterialprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterialprop
    ADD CONSTRAINT biomaterialprop_pkey PRIMARY KEY (biomaterialprop_id);


--
-- Name: blast_organisms_blast_org_name_uq_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.blast_organisms
    ADD CONSTRAINT blast_organisms_blast_org_name_uq_key UNIQUE (blast_org_name);


--
-- Name: blast_organisms_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.blast_organisms
    ADD CONSTRAINT blast_organisms_pkey PRIMARY KEY (blast_org_id);


--
-- Name: cell_line_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line
    ADD CONSTRAINT cell_line_c1 UNIQUE (uniquename, organism_id);


--
-- Name: cell_line_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm
    ADD CONSTRAINT cell_line_cvterm_c1 UNIQUE (cell_line_id, cvterm_id, pub_id, rank);


--
-- Name: cell_line_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm
    ADD CONSTRAINT cell_line_cvterm_pkey PRIMARY KEY (cell_line_cvterm_id);


--
-- Name: cell_line_cvtermprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvtermprop
    ADD CONSTRAINT cell_line_cvtermprop_c1 UNIQUE (cell_line_cvterm_id, type_id, rank);


--
-- Name: cell_line_cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvtermprop
    ADD CONSTRAINT cell_line_cvtermprop_pkey PRIMARY KEY (cell_line_cvtermprop_id);


--
-- Name: cell_line_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_dbxref
    ADD CONSTRAINT cell_line_dbxref_c1 UNIQUE (cell_line_id, dbxref_id);


--
-- Name: cell_line_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_dbxref
    ADD CONSTRAINT cell_line_dbxref_pkey PRIMARY KEY (cell_line_dbxref_id);


--
-- Name: cell_line_feature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature
    ADD CONSTRAINT cell_line_feature_c1 UNIQUE (cell_line_id, feature_id, pub_id);


--
-- Name: cell_line_feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature
    ADD CONSTRAINT cell_line_feature_pkey PRIMARY KEY (cell_line_feature_id);


--
-- Name: cell_line_library_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library
    ADD CONSTRAINT cell_line_library_c1 UNIQUE (cell_line_id, library_id, pub_id);


--
-- Name: cell_line_library_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library
    ADD CONSTRAINT cell_line_library_pkey PRIMARY KEY (cell_line_library_id);


--
-- Name: cell_line_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line
    ADD CONSTRAINT cell_line_pkey PRIMARY KEY (cell_line_id);


--
-- Name: cell_line_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_pub
    ADD CONSTRAINT cell_line_pub_c1 UNIQUE (cell_line_id, pub_id);


--
-- Name: cell_line_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_pub
    ADD CONSTRAINT cell_line_pub_pkey PRIMARY KEY (cell_line_pub_id);


--
-- Name: cell_line_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship
    ADD CONSTRAINT cell_line_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: cell_line_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship
    ADD CONSTRAINT cell_line_relationship_pkey PRIMARY KEY (cell_line_relationship_id);


--
-- Name: cell_line_synonym_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym
    ADD CONSTRAINT cell_line_synonym_c1 UNIQUE (synonym_id, cell_line_id, pub_id);


--
-- Name: cell_line_synonym_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym
    ADD CONSTRAINT cell_line_synonym_pkey PRIMARY KEY (cell_line_synonym_id);


--
-- Name: cell_lineprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop
    ADD CONSTRAINT cell_lineprop_c1 UNIQUE (cell_line_id, type_id, rank);


--
-- Name: cell_lineprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop
    ADD CONSTRAINT cell_lineprop_pkey PRIMARY KEY (cell_lineprop_id);


--
-- Name: cell_lineprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop_pub
    ADD CONSTRAINT cell_lineprop_pub_c1 UNIQUE (cell_lineprop_id, pub_id);


--
-- Name: cell_lineprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop_pub
    ADD CONSTRAINT cell_lineprop_pub_pkey PRIMARY KEY (cell_lineprop_pub_id);


--
-- Name: chado_gene_nid_vid_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chado_gene
    ADD CONSTRAINT chado_gene_nid_vid_key UNIQUE (nid, vid);


--
-- Name: chado_gene_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chado_gene
    ADD CONSTRAINT chado_gene_pkey PRIMARY KEY (nid);


--
-- Name: chado_gene_vid_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chado_gene
    ADD CONSTRAINT chado_gene_vid_key UNIQUE (vid);


--
-- Name: chadoprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chadoprop
    ADD CONSTRAINT chadoprop_c1 UNIQUE (type_id, rank);


--
-- Name: chadoprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chadoprop
    ADD CONSTRAINT chadoprop_pkey PRIMARY KEY (chadoprop_id);


--
-- Name: channel_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.channel
    ADD CONSTRAINT channel_c1 UNIQUE (name);


--
-- Name: channel_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.channel
    ADD CONSTRAINT channel_pkey PRIMARY KEY (channel_id);


--
-- Name: contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact
    ADD CONSTRAINT contact_c1 UNIQUE (name);


--
-- Name: contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (contact_id);


--
-- Name: contact_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship
    ADD CONSTRAINT contact_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: contact_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship
    ADD CONSTRAINT contact_relationship_pkey PRIMARY KEY (contact_relationship_id);


--
-- Name: contactprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop
    ADD CONSTRAINT contactprop_c1 UNIQUE (contact_id, type_id, rank);


--
-- Name: contactprop_contactprop_c1_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop
    ADD CONSTRAINT contactprop_contactprop_c1_key UNIQUE (contact_id, type_id, rank);


--
-- Name: contactprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop
    ADD CONSTRAINT contactprop_pkey PRIMARY KEY (contactprop_id);


--
-- Name: control_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.control
    ADD CONSTRAINT control_pkey PRIMARY KEY (control_id);


--
-- Name: cv_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cv
    ADD CONSTRAINT cv_c1 UNIQUE (name);


--
-- Name: cv_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cv
    ADD CONSTRAINT cv_pkey PRIMARY KEY (cv_id);


--
-- Name: cvprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvprop
    ADD CONSTRAINT cvprop_c1 UNIQUE (cv_id, type_id, rank);


--
-- Name: cvprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvprop
    ADD CONSTRAINT cvprop_pkey PRIMARY KEY (cvprop_id);


--
-- Name: cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm
    ADD CONSTRAINT cvterm_c1 UNIQUE (name, cv_id, is_obsolete);


--
-- Name: cvterm_c2; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm
    ADD CONSTRAINT cvterm_c2 UNIQUE (dbxref_id);


--
-- Name: cvterm_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_c1 UNIQUE (cvterm_id, dbxref_id);


--
-- Name: cvterm_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_pkey PRIMARY KEY (cvterm_dbxref_id);


--
-- Name: cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm
    ADD CONSTRAINT cvterm_pkey PRIMARY KEY (cvterm_id);


--
-- Name: cvterm_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: cvterm_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_pkey PRIMARY KEY (cvterm_relationship_id);


--
-- Name: cvtermpath_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_c1 UNIQUE (subject_id, object_id, type_id, pathdistance);


--
-- Name: cvtermpath_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_pkey PRIMARY KEY (cvtermpath_id);


--
-- Name: cvtermprop_cvterm_id_type_id_value_rank_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermprop
    ADD CONSTRAINT cvtermprop_cvterm_id_type_id_value_rank_key UNIQUE (cvterm_id, type_id, value, rank);


--
-- Name: cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermprop
    ADD CONSTRAINT cvtermprop_pkey PRIMARY KEY (cvtermprop_id);


--
-- Name: cvtermsynonym_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_c1 UNIQUE (cvterm_id, synonym);


--
-- Name: cvtermsynonym_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_pkey PRIMARY KEY (cvtermsynonym_id);


--
-- Name: db_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.db
    ADD CONSTRAINT db_c1 UNIQUE (name);


--
-- Name: db_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.db
    ADD CONSTRAINT db_pkey PRIMARY KEY (db_id);


--
-- Name: dbprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbprop
    ADD CONSTRAINT dbprop_c1 UNIQUE (db_id, type_id, rank);


--
-- Name: dbprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbprop
    ADD CONSTRAINT dbprop_pkey PRIMARY KEY (dbprop_id);


--
-- Name: dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxref
    ADD CONSTRAINT dbxref_c1 UNIQUE (db_id, accession, version);


--
-- Name: dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxref
    ADD CONSTRAINT dbxref_pkey PRIMARY KEY (dbxref_id);


--
-- Name: dbxrefprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxrefprop
    ADD CONSTRAINT dbxrefprop_c1 UNIQUE (dbxref_id, type_id, rank);


--
-- Name: dbxrefprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxrefprop
    ADD CONSTRAINT dbxrefprop_pkey PRIMARY KEY (dbxrefprop_id);


--
-- Name: domain_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.domain
    ADD CONSTRAINT domain_pkey PRIMARY KEY (feature_feature_id);


--
-- Name: eimage_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.eimage
    ADD CONSTRAINT eimage_pkey PRIMARY KEY (eimage_id);


--
-- Name: element_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_c1 UNIQUE (feature_id, arraydesign_id);


--
-- Name: element_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_pkey PRIMARY KEY (element_id);


--
-- Name: element_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship
    ADD CONSTRAINT element_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: element_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship
    ADD CONSTRAINT element_relationship_pkey PRIMARY KEY (element_relationship_id);


--
-- Name: elementresult_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult
    ADD CONSTRAINT elementresult_c1 UNIQUE (element_id, quantification_id);


--
-- Name: elementresult_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult
    ADD CONSTRAINT elementresult_pkey PRIMARY KEY (elementresult_id);


--
-- Name: elementresult_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship
    ADD CONSTRAINT elementresult_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: elementresult_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship
    ADD CONSTRAINT elementresult_relationship_pkey PRIMARY KEY (elementresult_relationship_id);


--
-- Name: environment_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment
    ADD CONSTRAINT environment_c1 UNIQUE (uniquename);


--
-- Name: environment_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment_cvterm
    ADD CONSTRAINT environment_cvterm_c1 UNIQUE (environment_id, cvterm_id);


--
-- Name: environment_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment_cvterm
    ADD CONSTRAINT environment_cvterm_pkey PRIMARY KEY (environment_cvterm_id);


--
-- Name: environment_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment
    ADD CONSTRAINT environment_pkey PRIMARY KEY (environment_id);


--
-- Name: expression_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression
    ADD CONSTRAINT expression_c1 UNIQUE (uniquename);


--
-- Name: expression_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm
    ADD CONSTRAINT expression_cvterm_c1 UNIQUE (expression_id, cvterm_id, rank, cvterm_type_id);


--
-- Name: expression_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm
    ADD CONSTRAINT expression_cvterm_pkey PRIMARY KEY (expression_cvterm_id);


--
-- Name: expression_cvtermprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvtermprop
    ADD CONSTRAINT expression_cvtermprop_c1 UNIQUE (expression_cvterm_id, type_id, rank);


--
-- Name: expression_cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvtermprop
    ADD CONSTRAINT expression_cvtermprop_pkey PRIMARY KEY (expression_cvtermprop_id);


--
-- Name: expression_image_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_image
    ADD CONSTRAINT expression_image_c1 UNIQUE (expression_id, eimage_id);


--
-- Name: expression_image_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_image
    ADD CONSTRAINT expression_image_pkey PRIMARY KEY (expression_image_id);


--
-- Name: expression_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression
    ADD CONSTRAINT expression_pkey PRIMARY KEY (expression_id);


--
-- Name: expression_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_pub
    ADD CONSTRAINT expression_pub_c1 UNIQUE (expression_id, pub_id);


--
-- Name: expression_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_pub
    ADD CONSTRAINT expression_pub_pkey PRIMARY KEY (expression_pub_id);


--
-- Name: expressionprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expressionprop
    ADD CONSTRAINT expressionprop_c1 UNIQUE (expression_id, type_id, rank);


--
-- Name: expressionprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expressionprop
    ADD CONSTRAINT expressionprop_pkey PRIMARY KEY (expressionprop_id);


--
-- Name: feature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature
    ADD CONSTRAINT feature_c1 UNIQUE (organism_id, uniquename, type_id);


--
-- Name: feature_contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_contact
    ADD CONSTRAINT feature_contact_c1 UNIQUE (feature_id, contact_id);


--
-- Name: feature_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_contact
    ADD CONSTRAINT feature_contact_pkey PRIMARY KEY (feature_contact_id);


--
-- Name: feature_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm
    ADD CONSTRAINT feature_cvterm_c1 UNIQUE (feature_id, cvterm_id, pub_id, rank);


--
-- Name: feature_cvterm_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_c1 UNIQUE (feature_cvterm_id, dbxref_id);


--
-- Name: feature_cvterm_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_pkey PRIMARY KEY (feature_cvterm_dbxref_id);


--
-- Name: feature_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm
    ADD CONSTRAINT feature_cvterm_pkey PRIMARY KEY (feature_cvterm_id);


--
-- Name: feature_cvterm_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_c1 UNIQUE (feature_cvterm_id, pub_id);


--
-- Name: feature_cvterm_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_pkey PRIMARY KEY (feature_cvterm_pub_id);


--
-- Name: feature_cvtermprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_c1 UNIQUE (feature_cvterm_id, type_id, rank);


--
-- Name: feature_cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_pkey PRIMARY KEY (feature_cvtermprop_id);


--
-- Name: feature_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_dbxref
    ADD CONSTRAINT feature_dbxref_c1 UNIQUE (feature_id, dbxref_id);


--
-- Name: feature_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_dbxref
    ADD CONSTRAINT feature_dbxref_pkey PRIMARY KEY (feature_dbxref_id);


--
-- Name: feature_expression_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression
    ADD CONSTRAINT feature_expression_c1 UNIQUE (expression_id, feature_id, pub_id);


--
-- Name: feature_expression_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression
    ADD CONSTRAINT feature_expression_pkey PRIMARY KEY (feature_expression_id);


--
-- Name: feature_expressionprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expressionprop
    ADD CONSTRAINT feature_expressionprop_c1 UNIQUE (feature_expression_id, type_id, rank);


--
-- Name: feature_expressionprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expressionprop
    ADD CONSTRAINT feature_expressionprop_pkey PRIMARY KEY (feature_expressionprop_id);


--
-- Name: feature_genotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_c1 UNIQUE (feature_id, genotype_id, cvterm_id, chromosome_id, rank, cgroup);


--
-- Name: feature_genotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_pkey PRIMARY KEY (feature_genotype_id);


--
-- Name: feature_phenotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_phenotype
    ADD CONSTRAINT feature_phenotype_c1 UNIQUE (feature_id, phenotype_id);


--
-- Name: feature_phenotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_phenotype
    ADD CONSTRAINT feature_phenotype_pkey PRIMARY KEY (feature_phenotype_id);


--
-- Name: feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature
    ADD CONSTRAINT feature_pkey PRIMARY KEY (feature_id);


--
-- Name: feature_project_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_project
    ADD CONSTRAINT feature_project_c1 UNIQUE (feature_id, project_id, rank);


--
-- Name: feature_project_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_project
    ADD CONSTRAINT feature_project_pkey PRIMARY KEY (feature_project_id);


--
-- Name: feature_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pub
    ADD CONSTRAINT feature_pub_c1 UNIQUE (feature_id, pub_id);


--
-- Name: feature_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pub
    ADD CONSTRAINT feature_pub_pkey PRIMARY KEY (feature_pub_id);


--
-- Name: feature_pubprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pubprop
    ADD CONSTRAINT feature_pubprop_c1 UNIQUE (feature_pub_id, type_id, rank);


--
-- Name: feature_pubprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pubprop
    ADD CONSTRAINT feature_pubprop_pkey PRIMARY KEY (feature_pubprop_id);


--
-- Name: feature_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship
    ADD CONSTRAINT feature_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: feature_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship
    ADD CONSTRAINT feature_relationship_pkey PRIMARY KEY (feature_relationship_id);


--
-- Name: feature_relationship_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_c1 UNIQUE (feature_relationship_id, pub_id);


--
-- Name: feature_relationship_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_pkey PRIMARY KEY (feature_relationship_pub_id);


--
-- Name: feature_relationshipprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_c1 UNIQUE (feature_relationship_id, type_id, rank);


--
-- Name: feature_relationshipprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_pkey PRIMARY KEY (feature_relationshipprop_id);


--
-- Name: feature_relationshipprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_c1 UNIQUE (feature_relationshipprop_id, pub_id);


--
-- Name: feature_relationshipprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_pkey PRIMARY KEY (feature_relationshipprop_pub_id);


--
-- Name: feature_stock_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock
    ADD CONSTRAINT feature_stock_c1 UNIQUE (feature_id, stock_id, type_id, rank);


--
-- Name: feature_stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock
    ADD CONSTRAINT feature_stock_pkey PRIMARY KEY (feature_stock_id);


--
-- Name: feature_synonym_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym
    ADD CONSTRAINT feature_synonym_c1 UNIQUE (synonym_id, feature_id, pub_id);


--
-- Name: feature_synonym_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym
    ADD CONSTRAINT feature_synonym_pkey PRIMARY KEY (feature_synonym_id);


--
-- Name: featureloc_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc
    ADD CONSTRAINT featureloc_c1 UNIQUE (feature_id, locgroup, rank);


--
-- Name: featureloc_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc
    ADD CONSTRAINT featureloc_pkey PRIMARY KEY (featureloc_id);


--
-- Name: featureloc_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc_pub
    ADD CONSTRAINT featureloc_pub_c1 UNIQUE (featureloc_id, pub_id);


--
-- Name: featureloc_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc_pub
    ADD CONSTRAINT featureloc_pub_pkey PRIMARY KEY (featureloc_pub_id);


--
-- Name: featurelocprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurelocprop
    ADD CONSTRAINT featurelocprop_c1 UNIQUE (featureloc_id, type_id, rank);


--
-- Name: featurelocprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurelocprop
    ADD CONSTRAINT featurelocprop_pkey PRIMARY KEY (featurelocprop_id);


--
-- Name: featuremap_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap
    ADD CONSTRAINT featuremap_c1 UNIQUE (name);


--
-- Name: featuremap_contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_contact
    ADD CONSTRAINT featuremap_contact_c1 UNIQUE (featuremap_id, contact_id);


--
-- Name: featuremap_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_contact
    ADD CONSTRAINT featuremap_contact_pkey PRIMARY KEY (featuremap_contact_id);


--
-- Name: featuremap_dbxref_featuremap_dbxref_c1_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_dbxref
    ADD CONSTRAINT featuremap_dbxref_featuremap_dbxref_c1_key UNIQUE (featuremap_id, dbxref_id);


--
-- Name: featuremap_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_dbxref
    ADD CONSTRAINT featuremap_dbxref_pkey PRIMARY KEY (featuremap_dbxref_id);


--
-- Name: featuremap_organism_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_organism
    ADD CONSTRAINT featuremap_organism_c1 UNIQUE (featuremap_id, organism_id);


--
-- Name: featuremap_organism_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_organism
    ADD CONSTRAINT featuremap_organism_pkey PRIMARY KEY (featuremap_organism_id);


--
-- Name: featuremap_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap
    ADD CONSTRAINT featuremap_pkey PRIMARY KEY (featuremap_id);


--
-- Name: featuremap_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_pub
    ADD CONSTRAINT featuremap_pub_pkey PRIMARY KEY (featuremap_pub_id);


--
-- Name: featuremap_stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_stock
    ADD CONSTRAINT featuremap_stock_pkey PRIMARY KEY (featuremap_stock_id);


--
-- Name: featuremapprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop
    ADD CONSTRAINT featuremapprop_c1 UNIQUE (featuremap_id, type_id, rank);


--
-- Name: featuremapprop_featuremapprop_c1_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop
    ADD CONSTRAINT featuremapprop_featuremapprop_c1_key UNIQUE (featuremap_id, type_id, rank);


--
-- Name: featuremapprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop
    ADD CONSTRAINT featuremapprop_pkey PRIMARY KEY (featuremapprop_id);


--
-- Name: featurepos_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurepos
    ADD CONSTRAINT featurepos_pkey PRIMARY KEY (featurepos_id);


--
-- Name: featureposprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop
    ADD CONSTRAINT featureposprop_c1 UNIQUE (featurepos_id, type_id, rank);


--
-- Name: featureposprop_featureposprop_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop
    ADD CONSTRAINT featureposprop_featureposprop_id_key UNIQUE (featurepos_id, type_id, rank);


--
-- Name: featureposprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop
    ADD CONSTRAINT featureposprop_pkey PRIMARY KEY (featureposprop_id);


--
-- Name: featureprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop
    ADD CONSTRAINT featureprop_c1 UNIQUE (feature_id, type_id, rank);


--
-- Name: featureprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop
    ADD CONSTRAINT featureprop_pkey PRIMARY KEY (featureprop_id);


--
-- Name: featureprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop_pub
    ADD CONSTRAINT featureprop_pub_c1 UNIQUE (featureprop_id, pub_id);


--
-- Name: featureprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop_pub
    ADD CONSTRAINT featureprop_pub_pkey PRIMARY KEY (featureprop_pub_id);


--
-- Name: featurerange_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_pkey PRIMARY KEY (featurerange_id);


--
-- Name: gene_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.gene
    ADD CONSTRAINT gene_pkey PRIMARY KEY (gene_id);


--
-- Name: genotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotype
    ADD CONSTRAINT genotype_c1 UNIQUE (uniquename);


--
-- Name: genotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotype
    ADD CONSTRAINT genotype_pkey PRIMARY KEY (genotype_id);


--
-- Name: genotypeprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotypeprop
    ADD CONSTRAINT genotypeprop_c1 UNIQUE (genotype_id, type_id, rank);


--
-- Name: genotypeprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotypeprop
    ADD CONSTRAINT genotypeprop_pkey PRIMARY KEY (genotypeprop_id);


--
-- Name: library_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library
    ADD CONSTRAINT library_c1 UNIQUE (organism_id, uniquename, type_id);


--
-- Name: library_contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_contact
    ADD CONSTRAINT library_contact_c1 UNIQUE (library_id, contact_id);


--
-- Name: library_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_contact
    ADD CONSTRAINT library_contact_pkey PRIMARY KEY (library_contact_id);


--
-- Name: library_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm
    ADD CONSTRAINT library_cvterm_c1 UNIQUE (library_id, cvterm_id, pub_id);


--
-- Name: library_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm
    ADD CONSTRAINT library_cvterm_pkey PRIMARY KEY (library_cvterm_id);


--
-- Name: library_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_dbxref
    ADD CONSTRAINT library_dbxref_c1 UNIQUE (library_id, dbxref_id);


--
-- Name: library_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_dbxref
    ADD CONSTRAINT library_dbxref_pkey PRIMARY KEY (library_dbxref_id);


--
-- Name: library_expression_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression
    ADD CONSTRAINT library_expression_c1 UNIQUE (library_id, expression_id);


--
-- Name: library_expression_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression
    ADD CONSTRAINT library_expression_pkey PRIMARY KEY (library_expression_id);


--
-- Name: library_expressionprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expressionprop
    ADD CONSTRAINT library_expressionprop_c1 UNIQUE (library_expression_id, type_id, rank);


--
-- Name: library_expressionprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expressionprop
    ADD CONSTRAINT library_expressionprop_pkey PRIMARY KEY (library_expressionprop_id);


--
-- Name: library_feature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_feature
    ADD CONSTRAINT library_feature_c1 UNIQUE (library_id, feature_id);


--
-- Name: library_feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_feature
    ADD CONSTRAINT library_feature_pkey PRIMARY KEY (library_feature_id);


--
-- Name: library_featureprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_featureprop
    ADD CONSTRAINT library_featureprop_c1 UNIQUE (library_feature_id, type_id, rank);


--
-- Name: library_featureprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_featureprop
    ADD CONSTRAINT library_featureprop_pkey PRIMARY KEY (library_featureprop_id);


--
-- Name: library_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library
    ADD CONSTRAINT library_pkey PRIMARY KEY (library_id);


--
-- Name: library_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_pub
    ADD CONSTRAINT library_pub_c1 UNIQUE (library_id, pub_id);


--
-- Name: library_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_pub
    ADD CONSTRAINT library_pub_pkey PRIMARY KEY (library_pub_id);


--
-- Name: library_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship
    ADD CONSTRAINT library_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: library_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship
    ADD CONSTRAINT library_relationship_pkey PRIMARY KEY (library_relationship_id);


--
-- Name: library_relationship_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship_pub
    ADD CONSTRAINT library_relationship_pub_c1 UNIQUE (library_relationship_id, pub_id);


--
-- Name: library_relationship_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship_pub
    ADD CONSTRAINT library_relationship_pub_pkey PRIMARY KEY (library_relationship_pub_id);


--
-- Name: library_synonym_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym
    ADD CONSTRAINT library_synonym_c1 UNIQUE (synonym_id, library_id, pub_id);


--
-- Name: library_synonym_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym
    ADD CONSTRAINT library_synonym_pkey PRIMARY KEY (library_synonym_id);


--
-- Name: libraryprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop
    ADD CONSTRAINT libraryprop_c1 UNIQUE (library_id, type_id, rank);


--
-- Name: libraryprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop
    ADD CONSTRAINT libraryprop_pkey PRIMARY KEY (libraryprop_id);


--
-- Name: libraryprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop_pub
    ADD CONSTRAINT libraryprop_pub_c1 UNIQUE (libraryprop_id, pub_id);


--
-- Name: libraryprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop_pub
    ADD CONSTRAINT libraryprop_pub_pkey PRIMARY KEY (libraryprop_pub_id);


--
-- Name: lightshop_order_nid_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.lightshop_order
    ADD CONSTRAINT lightshop_order_nid_key UNIQUE (nid);


--
-- Name: lightshop_order_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.lightshop_order
    ADD CONSTRAINT lightshop_order_pkey PRIMARY KEY (oid);


--
-- Name: magedocumentation_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.magedocumentation
    ADD CONSTRAINT magedocumentation_pkey PRIMARY KEY (magedocumentation_id);


--
-- Name: mageml_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.mageml
    ADD CONSTRAINT mageml_pkey PRIMARY KEY (mageml_id);


--
-- Name: materialized_view_name_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.materialized_view
    ADD CONSTRAINT materialized_view_name_key UNIQUE (name);


--
-- Name: nd_experiment_analysis_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_analysis
    ADD CONSTRAINT nd_experiment_analysis_pkey PRIMARY KEY (nd_experiment_analysis_id);


--
-- Name: nd_experiment_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_pkey PRIMARY KEY (nd_experiment_contact_id);


--
-- Name: nd_experiment_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_pkey PRIMARY KEY (nd_experiment_dbxref_id);


--
-- Name: nd_experiment_genotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_c1 UNIQUE (nd_experiment_id, genotype_id);


--
-- Name: nd_experiment_genotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_pkey PRIMARY KEY (nd_experiment_genotype_id);


--
-- Name: nd_experiment_phenotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_c1 UNIQUE (nd_experiment_id, phenotype_id);


--
-- Name: nd_experiment_phenotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_pkey PRIMARY KEY (nd_experiment_phenotype_id);


--
-- Name: nd_experiment_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment
    ADD CONSTRAINT nd_experiment_pkey PRIMARY KEY (nd_experiment_id);


--
-- Name: nd_experiment_project_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_c1 UNIQUE (project_id, nd_experiment_id);


--
-- Name: nd_experiment_project_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_pkey PRIMARY KEY (nd_experiment_project_id);


--
-- Name: nd_experiment_protocol_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_pkey PRIMARY KEY (nd_experiment_protocol_id);


--
-- Name: nd_experiment_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_c1 UNIQUE (nd_experiment_id, pub_id);


--
-- Name: nd_experiment_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_pkey PRIMARY KEY (nd_experiment_pub_id);


--
-- Name: nd_experiment_stock_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_pkey PRIMARY KEY (nd_experiment_stock_dbxref_id);


--
-- Name: nd_experiment_stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_pkey PRIMARY KEY (nd_experiment_stock_id);


--
-- Name: nd_experiment_stockprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_c1 UNIQUE (nd_experiment_stock_id, type_id, rank);


--
-- Name: nd_experiment_stockprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_pkey PRIMARY KEY (nd_experiment_stockprop_id);


--
-- Name: nd_experimentprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_c1 UNIQUE (nd_experiment_id, type_id, rank);


--
-- Name: nd_experimentprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_pkey PRIMARY KEY (nd_experimentprop_id);


--
-- Name: nd_geolocation_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocation
    ADD CONSTRAINT nd_geolocation_pkey PRIMARY KEY (nd_geolocation_id);


--
-- Name: nd_geolocationprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_c1 UNIQUE (nd_geolocation_id, type_id, rank);


--
-- Name: nd_geolocationprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_pkey PRIMARY KEY (nd_geolocationprop_id);


--
-- Name: nd_protocol_name_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol
    ADD CONSTRAINT nd_protocol_name_key UNIQUE (name);


--
-- Name: nd_protocol_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol
    ADD CONSTRAINT nd_protocol_pkey PRIMARY KEY (nd_protocol_id);


--
-- Name: nd_protocol_reagent_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_pkey PRIMARY KEY (nd_protocol_reagent_id);


--
-- Name: nd_protocolprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_c1 UNIQUE (nd_protocol_id, type_id, rank);


--
-- Name: nd_protocolprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_pkey PRIMARY KEY (nd_protocolprop_id);


--
-- Name: nd_reagent_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent
    ADD CONSTRAINT nd_reagent_pkey PRIMARY KEY (nd_reagent_id);


--
-- Name: nd_reagent_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_pkey PRIMARY KEY (nd_reagent_relationship_id);


--
-- Name: nd_reagentprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_c1 UNIQUE (nd_reagent_id, type_id, rank);


--
-- Name: nd_reagentprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_pkey PRIMARY KEY (nd_reagentprop_id);


--
-- Name: organism_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism
    ADD CONSTRAINT organism_c1 UNIQUE (genus, species, type_id, infraspecific_name);


--
-- Name: organism_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm
    ADD CONSTRAINT organism_cvterm_c1 UNIQUE (organism_id, cvterm_id, pub_id);


--
-- Name: organism_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm
    ADD CONSTRAINT organism_cvterm_pkey PRIMARY KEY (organism_cvterm_id);


--
-- Name: organism_cvtermprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvtermprop
    ADD CONSTRAINT organism_cvtermprop_c1 UNIQUE (organism_cvterm_id, type_id, rank);


--
-- Name: organism_cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvtermprop
    ADD CONSTRAINT organism_cvtermprop_pkey PRIMARY KEY (organism_cvtermprop_id);


--
-- Name: organism_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_dbxref
    ADD CONSTRAINT organism_dbxref_c1 UNIQUE (organism_id, dbxref_id);


--
-- Name: organism_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_dbxref
    ADD CONSTRAINT organism_dbxref_pkey PRIMARY KEY (organism_dbxref_id);


--
-- Name: organism_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism
    ADD CONSTRAINT organism_pkey PRIMARY KEY (organism_id);


--
-- Name: organism_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_pub
    ADD CONSTRAINT organism_pub_c1 UNIQUE (organism_id, pub_id);


--
-- Name: organism_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_pub
    ADD CONSTRAINT organism_pub_pkey PRIMARY KEY (organism_pub_id);


--
-- Name: organism_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship
    ADD CONSTRAINT organism_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: organism_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship
    ADD CONSTRAINT organism_relationship_pkey PRIMARY KEY (organism_relationship_id);


--
-- Name: organismprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop
    ADD CONSTRAINT organismprop_c1 UNIQUE (organism_id, type_id, rank);


--
-- Name: organismprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop
    ADD CONSTRAINT organismprop_pkey PRIMARY KEY (organismprop_id);


--
-- Name: organismprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop_pub
    ADD CONSTRAINT organismprop_pub_c1 UNIQUE (organismprop_id, pub_id);


--
-- Name: organismprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop_pub
    ADD CONSTRAINT organismprop_pub_pkey PRIMARY KEY (organismprop_pub_id);


--
-- Name: phendesc_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_c1 UNIQUE (genotype_id, environment_id, type_id, pub_id);


--
-- Name: phendesc_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_pkey PRIMARY KEY (phendesc_id);


--
-- Name: phenotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_c1 UNIQUE (uniquename);


--
-- Name: phenotype_comparison_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_c1 UNIQUE (genotype1_id, environment1_id, genotype2_id, environment2_id, phenotype1_id, pub_id);


--
-- Name: phenotype_comparison_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_c1 UNIQUE (phenotype_comparison_id, cvterm_id);


--
-- Name: phenotype_comparison_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_pkey PRIMARY KEY (phenotype_comparison_cvterm_id);


--
-- Name: phenotype_comparison_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_pkey PRIMARY KEY (phenotype_comparison_id);


--
-- Name: phenotype_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_c1 UNIQUE (phenotype_id, cvterm_id, rank);


--
-- Name: phenotype_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_pkey PRIMARY KEY (phenotype_cvterm_id);


--
-- Name: phenotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_pkey PRIMARY KEY (phenotype_id);


--
-- Name: phenotypeprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotypeprop
    ADD CONSTRAINT phenotypeprop_c1 UNIQUE (phenotype_id, type_id, rank);


--
-- Name: phenotypeprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotypeprop
    ADD CONSTRAINT phenotypeprop_pkey PRIMARY KEY (phenotypeprop_id);


--
-- Name: phenstatement_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_c1 UNIQUE (genotype_id, phenotype_id, environment_id, type_id, pub_id);


--
-- Name: phenstatement_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_pkey PRIMARY KEY (phenstatement_id);


--
-- Name: phylonode_dbxref_phylonode_id_dbxref_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_dbxref
    ADD CONSTRAINT phylonode_dbxref_phylonode_id_dbxref_id_key UNIQUE (phylonode_id, dbxref_id);


--
-- Name: phylonode_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_dbxref
    ADD CONSTRAINT phylonode_dbxref_pkey PRIMARY KEY (phylonode_dbxref_id);


--
-- Name: phylonode_organism_phylonode_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_organism
    ADD CONSTRAINT phylonode_organism_phylonode_id_key UNIQUE (phylonode_id);


--
-- Name: phylonode_organism_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_organism
    ADD CONSTRAINT phylonode_organism_pkey PRIMARY KEY (phylonode_organism_id);


--
-- Name: phylonode_phylotree_id_left_idx_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_phylotree_id_left_idx_key UNIQUE (phylotree_id, left_idx);


--
-- Name: phylonode_phylotree_id_right_idx_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_phylotree_id_right_idx_key UNIQUE (phylotree_id, right_idx);


--
-- Name: phylonode_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_pkey PRIMARY KEY (phylonode_id);


--
-- Name: phylonode_pub_phylonode_id_pub_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_pub
    ADD CONSTRAINT phylonode_pub_phylonode_id_pub_id_key UNIQUE (phylonode_id, pub_id);


--
-- Name: phylonode_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_pub
    ADD CONSTRAINT phylonode_pub_pkey PRIMARY KEY (phylonode_pub_id);


--
-- Name: phylonode_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_pkey PRIMARY KEY (phylonode_relationship_id);


--
-- Name: phylonode_relationship_subject_id_object_id_type_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_subject_id_object_id_type_id_key UNIQUE (subject_id, object_id, type_id);


--
-- Name: phylonodeprop_phylonode_id_type_id_value_rank_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonodeprop
    ADD CONSTRAINT phylonodeprop_phylonode_id_type_id_value_rank_key UNIQUE (phylonode_id, type_id, value, rank);


--
-- Name: phylonodeprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonodeprop
    ADD CONSTRAINT phylonodeprop_pkey PRIMARY KEY (phylonodeprop_id);


--
-- Name: phylotree_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree
    ADD CONSTRAINT phylotree_pkey PRIMARY KEY (phylotree_id);


--
-- Name: phylotree_pub_phylotree_id_pub_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree_pub
    ADD CONSTRAINT phylotree_pub_phylotree_id_pub_id_key UNIQUE (phylotree_id, pub_id);


--
-- Name: phylotree_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree_pub
    ADD CONSTRAINT phylotree_pub_pkey PRIMARY KEY (phylotree_pub_id);


--
-- Name: phylotreeprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotreeprop
    ADD CONSTRAINT phylotreeprop_c1 UNIQUE (phylotree_id, type_id, rank);


--
-- Name: phylotreeprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotreeprop
    ADD CONSTRAINT phylotreeprop_pkey PRIMARY KEY (phylotreeprop_id);


--
-- Name: project_analysis_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_analysis
    ADD CONSTRAINT project_analysis_c1 UNIQUE (project_id, analysis_id);


--
-- Name: project_analysis_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_analysis
    ADD CONSTRAINT project_analysis_pkey PRIMARY KEY (project_analysis_id);


--
-- Name: project_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project
    ADD CONSTRAINT project_c1 UNIQUE (name);


--
-- Name: project_contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_contact
    ADD CONSTRAINT project_contact_c1 UNIQUE (project_id, contact_id);


--
-- Name: project_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_contact
    ADD CONSTRAINT project_contact_pkey PRIMARY KEY (project_contact_id);


--
-- Name: project_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_dbxref
    ADD CONSTRAINT project_dbxref_c1 UNIQUE (project_id, dbxref_id);


--
-- Name: project_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_dbxref
    ADD CONSTRAINT project_dbxref_pkey PRIMARY KEY (project_dbxref_id);


--
-- Name: project_feature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_feature
    ADD CONSTRAINT project_feature_c1 UNIQUE (feature_id, project_id);


--
-- Name: project_feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_feature
    ADD CONSTRAINT project_feature_pkey PRIMARY KEY (project_feature_id);


--
-- Name: project_phenotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_phenotype
    ADD CONSTRAINT project_phenotype_pkey PRIMARY KEY (project_phenotype_id);


--
-- Name: project_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (project_id);


--
-- Name: project_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_pub
    ADD CONSTRAINT project_pub_c1 UNIQUE (project_id, pub_id);


--
-- Name: project_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_pub
    ADD CONSTRAINT project_pub_pkey PRIMARY KEY (project_pub_id);


--
-- Name: project_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship
    ADD CONSTRAINT project_relationship_c1 UNIQUE (subject_project_id, object_project_id, type_id);


--
-- Name: project_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship
    ADD CONSTRAINT project_relationship_pkey PRIMARY KEY (project_relationship_id);


--
-- Name: project_stock_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_stock
    ADD CONSTRAINT project_stock_c1 UNIQUE (stock_id, project_id);


--
-- Name: project_stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_stock
    ADD CONSTRAINT project_stock_pkey PRIMARY KEY (project_stock_id);


--
-- Name: projectprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.projectprop
    ADD CONSTRAINT projectprop_c1 UNIQUE (project_id, type_id, rank);


--
-- Name: projectprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.projectprop
    ADD CONSTRAINT projectprop_pkey PRIMARY KEY (projectprop_id);


--
-- Name: protocol_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol
    ADD CONSTRAINT protocol_c1 UNIQUE (name);


--
-- Name: protocol_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol
    ADD CONSTRAINT protocol_pkey PRIMARY KEY (protocol_id);


--
-- Name: protocolparam_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocolparam
    ADD CONSTRAINT protocolparam_pkey PRIMARY KEY (protocolparam_id);


--
-- Name: pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub
    ADD CONSTRAINT pub_c1 UNIQUE (uniquename);


--
-- Name: pub_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_dbxref
    ADD CONSTRAINT pub_dbxref_c1 UNIQUE (pub_id, dbxref_id);


--
-- Name: pub_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_dbxref
    ADD CONSTRAINT pub_dbxref_pkey PRIMARY KEY (pub_dbxref_id);


--
-- Name: pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub
    ADD CONSTRAINT pub_pkey PRIMARY KEY (pub_id);


--
-- Name: pub_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship
    ADD CONSTRAINT pub_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: pub_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship
    ADD CONSTRAINT pub_relationship_pkey PRIMARY KEY (pub_relationship_id);


--
-- Name: pubauthor_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor
    ADD CONSTRAINT pubauthor_c1 UNIQUE (pub_id, rank);


--
-- Name: pubauthor_contact_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor_contact
    ADD CONSTRAINT pubauthor_contact_c1 UNIQUE (contact_id, pubauthor_id);


--
-- Name: pubauthor_contact_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor_contact
    ADD CONSTRAINT pubauthor_contact_pkey PRIMARY KEY (pubauthor_contact_id);


--
-- Name: pubauthor_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor
    ADD CONSTRAINT pubauthor_pkey PRIMARY KEY (pubauthor_id);


--
-- Name: pubprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubprop
    ADD CONSTRAINT pubprop_c1 UNIQUE (pub_id, type_id, rank);


--
-- Name: pubprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubprop
    ADD CONSTRAINT pubprop_pkey PRIMARY KEY (pubprop_id);


--
-- Name: quantification_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_c1 UNIQUE (name, analysis_id);


--
-- Name: quantification_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_pkey PRIMARY KEY (quantification_id);


--
-- Name: quantification_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship
    ADD CONSTRAINT quantification_relationship_c1 UNIQUE (subject_id, object_id, type_id);


--
-- Name: quantification_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship
    ADD CONSTRAINT quantification_relationship_pkey PRIMARY KEY (quantification_relationship_id);


--
-- Name: quantificationprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantificationprop
    ADD CONSTRAINT quantificationprop_c1 UNIQUE (quantification_id, type_id, rank);


--
-- Name: quantificationprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantificationprop
    ADD CONSTRAINT quantificationprop_pkey PRIMARY KEY (quantificationprop_id);


--
-- Name: stock_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock
    ADD CONSTRAINT stock_c1 UNIQUE (organism_id, uniquename, type_id);


--
-- Name: stock_cvterm_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm
    ADD CONSTRAINT stock_cvterm_c1 UNIQUE (stock_id, cvterm_id, pub_id, rank);


--
-- Name: stock_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm
    ADD CONSTRAINT stock_cvterm_pkey PRIMARY KEY (stock_cvterm_id);


--
-- Name: stock_cvtermprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_c1 UNIQUE (stock_cvterm_id, type_id, rank);


--
-- Name: stock_cvtermprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_pkey PRIMARY KEY (stock_cvtermprop_id);


--
-- Name: stock_dbxref_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxref
    ADD CONSTRAINT stock_dbxref_c1 UNIQUE (stock_id, dbxref_id);


--
-- Name: stock_dbxref_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxref
    ADD CONSTRAINT stock_dbxref_pkey PRIMARY KEY (stock_dbxref_id);


--
-- Name: stock_dbxrefprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_c1 UNIQUE (stock_dbxref_id, type_id, rank);


--
-- Name: stock_dbxrefprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_pkey PRIMARY KEY (stock_dbxrefprop_id);


--
-- Name: stock_eimage_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_eimage
    ADD CONSTRAINT stock_eimage_pkey PRIMARY KEY (stock_eimage_id);


--
-- Name: stock_feature_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature
    ADD CONSTRAINT stock_feature_c1 UNIQUE (feature_id, stock_id, type_id, rank);


--
-- Name: stock_feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature
    ADD CONSTRAINT stock_feature_pkey PRIMARY KEY (stock_feature_id);


--
-- Name: stock_featuremap_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_featuremap
    ADD CONSTRAINT stock_featuremap_c1 UNIQUE (featuremap_id, stock_id, type_id);


--
-- Name: stock_featuremap_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_featuremap
    ADD CONSTRAINT stock_featuremap_pkey PRIMARY KEY (stock_featuremap_id);


--
-- Name: stock_genotype_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_genotype
    ADD CONSTRAINT stock_genotype_c1 UNIQUE (stock_id, genotype_id);


--
-- Name: stock_genotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_genotype
    ADD CONSTRAINT stock_genotype_pkey PRIMARY KEY (stock_genotype_id);


--
-- Name: stock_library_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_library
    ADD CONSTRAINT stock_library_c1 UNIQUE (library_id, stock_id);


--
-- Name: stock_library_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_library
    ADD CONSTRAINT stock_library_pkey PRIMARY KEY (stock_library_id);


--
-- Name: stock_organism_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_organism
    ADD CONSTRAINT stock_organism_c1 UNIQUE (stock_id, organism_id, rank);


--
-- Name: stock_organism_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_organism
    ADD CONSTRAINT stock_organism_pkey PRIMARY KEY (stock_organism_id);


--
-- Name: stock_phenotype_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_phenotype
    ADD CONSTRAINT stock_phenotype_pkey PRIMARY KEY (stock_phenotype_id);


--
-- Name: stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock
    ADD CONSTRAINT stock_pkey PRIMARY KEY (stock_id);


--
-- Name: stock_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_pub
    ADD CONSTRAINT stock_pub_c1 UNIQUE (stock_id, pub_id);


--
-- Name: stock_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_pub
    ADD CONSTRAINT stock_pub_pkey PRIMARY KEY (stock_pub_id);


--
-- Name: stock_relationship_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship
    ADD CONSTRAINT stock_relationship_c1 UNIQUE (subject_id, object_id, type_id, rank);


--
-- Name: stock_relationship_cvterm_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_pkey PRIMARY KEY (stock_relationship_cvterm_id);


--
-- Name: stock_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship
    ADD CONSTRAINT stock_relationship_pkey PRIMARY KEY (stock_relationship_id);


--
-- Name: stock_relationship_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_c1 UNIQUE (stock_relationship_id, pub_id);


--
-- Name: stock_relationship_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_pkey PRIMARY KEY (stock_relationship_pub_id);


--
-- Name: stockcollection_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection
    ADD CONSTRAINT stockcollection_c1 UNIQUE (uniquename, type_id);


--
-- Name: stockcollection_db_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_db
    ADD CONSTRAINT stockcollection_db_c1 UNIQUE (stockcollection_id, db_id);


--
-- Name: stockcollection_db_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_db
    ADD CONSTRAINT stockcollection_db_pkey PRIMARY KEY (stockcollection_db_id);


--
-- Name: stockcollection_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection
    ADD CONSTRAINT stockcollection_pkey PRIMARY KEY (stockcollection_id);


--
-- Name: stockcollection_stock_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_c1 UNIQUE (stockcollection_id, stock_id);


--
-- Name: stockcollection_stock_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_pkey PRIMARY KEY (stockcollection_stock_id);


--
-- Name: stockcollectionprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_c1 UNIQUE (stockcollection_id, type_id, rank);


--
-- Name: stockcollectionprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_pkey PRIMARY KEY (stockcollectionprop_id);


--
-- Name: stockprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop
    ADD CONSTRAINT stockprop_c1 UNIQUE (stock_id, type_id, rank);


--
-- Name: stockprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop
    ADD CONSTRAINT stockprop_pkey PRIMARY KEY (stockprop_id);


--
-- Name: stockprop_pub_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop_pub
    ADD CONSTRAINT stockprop_pub_c1 UNIQUE (stockprop_id, pub_id);


--
-- Name: stockprop_pub_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop_pub
    ADD CONSTRAINT stockprop_pub_pkey PRIMARY KEY (stockprop_pub_id);


--
-- Name: study_assay_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study_assay
    ADD CONSTRAINT study_assay_c1 UNIQUE (study_id, assay_id);


--
-- Name: study_assay_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study_assay
    ADD CONSTRAINT study_assay_pkey PRIMARY KEY (study_assay_id);


--
-- Name: study_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study
    ADD CONSTRAINT study_c1 UNIQUE (name);


--
-- Name: study_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study
    ADD CONSTRAINT study_pkey PRIMARY KEY (study_id);


--
-- Name: studydesign_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesign
    ADD CONSTRAINT studydesign_pkey PRIMARY KEY (studydesign_id);


--
-- Name: studydesignprop_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesignprop
    ADD CONSTRAINT studydesignprop_c1 UNIQUE (studydesign_id, type_id, rank);


--
-- Name: studydesignprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesignprop
    ADD CONSTRAINT studydesignprop_pkey PRIMARY KEY (studydesignprop_id);


--
-- Name: studyfactor_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactor
    ADD CONSTRAINT studyfactor_pkey PRIMARY KEY (studyfactor_id);


--
-- Name: studyfactorvalue_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactorvalue
    ADD CONSTRAINT studyfactorvalue_pkey PRIMARY KEY (studyfactorvalue_id);


--
-- Name: studyprop_feature_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature
    ADD CONSTRAINT studyprop_feature_pkey PRIMARY KEY (studyprop_feature_id);


--
-- Name: studyprop_feature_studyprop_id_feature_id_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature
    ADD CONSTRAINT studyprop_feature_studyprop_id_feature_id_key UNIQUE (studyprop_id, feature_id);


--
-- Name: studyprop_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop
    ADD CONSTRAINT studyprop_pkey PRIMARY KEY (studyprop_id);


--
-- Name: studyprop_study_id_type_id_rank_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop
    ADD CONSTRAINT studyprop_study_id_type_id_rank_key UNIQUE (study_id, type_id, rank);


--
-- Name: synonym_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.synonym
    ADD CONSTRAINT synonym_c1 UNIQUE (name, type_id);


--
-- Name: synonym_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.synonym
    ADD CONSTRAINT synonym_pkey PRIMARY KEY (synonym_id);


--
-- Name: tableinfo_c1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tableinfo
    ADD CONSTRAINT tableinfo_c1 UNIQUE (name);


--
-- Name: tableinfo_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tableinfo
    ADD CONSTRAINT tableinfo_pkey PRIMARY KEY (tableinfo_id);


--
-- Name: tmp_cds_handler_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp_cds_handler
    ADD CONSTRAINT tmp_cds_handler_pkey PRIMARY KEY (cds_row_id);


--
-- Name: tmp_cds_handler_relationship_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp_cds_handler_relationship
    ADD CONSTRAINT tmp_cds_handler_relationship_pkey PRIMARY KEY (rel_row_id);


--
-- Name: treatment_pkey; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.treatment
    ADD CONSTRAINT treatment_pkey PRIMARY KEY (treatment_id);


--
-- Name: tripal_gff_temp_uq0; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tripal_gff_temp
    ADD CONSTRAINT tripal_gff_temp_uq0 UNIQUE (feature_id);


--
-- Name: tripal_gff_temp_uq1; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tripal_gff_temp
    ADD CONSTRAINT tripal_gff_temp_uq1 UNIQUE (uniquename, organism_id, type_name);


--
-- Name: tripal_gffprotein_temp_tripal_gff_temp_uq0_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tripal_gffprotein_temp
    ADD CONSTRAINT tripal_gffprotein_temp_tripal_gff_temp_uq0_key UNIQUE (feature_id);


--
-- Name: tripal_obo_temp_tripal_obo_temp_uq0_key; Type: CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tripal_obo_temp
    ADD CONSTRAINT tripal_obo_temp_tripal_obo_temp_uq0_key UNIQUE (id);


--
-- Name: acquisition_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_idx1 ON chado.acquisition USING btree (assay_id);


--
-- Name: acquisition_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_idx2 ON chado.acquisition USING btree (protocol_id);


--
-- Name: acquisition_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_idx3 ON chado.acquisition USING btree (channel_id);


--
-- Name: acquisition_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_relationship_idx1 ON chado.acquisition_relationship USING btree (subject_id);


--
-- Name: acquisition_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_relationship_idx2 ON chado.acquisition_relationship USING btree (type_id);


--
-- Name: acquisition_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisition_relationship_idx3 ON chado.acquisition_relationship USING btree (object_id);


--
-- Name: acquisitionprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisitionprop_idx1 ON chado.acquisitionprop USING btree (acquisition_id);


--
-- Name: acquisitionprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX acquisitionprop_idx2 ON chado.acquisitionprop USING btree (type_id);


--
-- Name: analysis_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_cvterm_idx1 ON chado.analysis_cvterm USING btree (analysis_id);


--
-- Name: analysis_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_cvterm_idx2 ON chado.analysis_cvterm USING btree (cvterm_id);


--
-- Name: analysis_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_dbxref_idx1 ON chado.analysis_dbxref USING btree (analysis_id);


--
-- Name: analysis_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_dbxref_idx2 ON chado.analysis_dbxref USING btree (dbxref_id);


--
-- Name: analysis_organism_networkmod_qtl_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_organism_networkmod_qtl_indx0_idx ON chado.analysis_organism USING btree (analysis_id);


--
-- Name: analysis_organism_networkmod_qtl_indx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_organism_networkmod_qtl_indx1_idx ON chado.analysis_organism USING btree (organism_id);


--
-- Name: analysis_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_pub_idx1 ON chado.analysis_pub USING btree (analysis_id);


--
-- Name: analysis_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_pub_idx2 ON chado.analysis_pub USING btree (pub_id);


--
-- Name: analysis_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_relationship_idx1 ON chado.analysis_relationship USING btree (subject_id);


--
-- Name: analysis_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_relationship_idx2 ON chado.analysis_relationship USING btree (object_id);


--
-- Name: analysis_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysis_relationship_idx3 ON chado.analysis_relationship USING btree (type_id);


--
-- Name: analysisfeature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisfeature_idx1 ON chado.analysisfeature USING btree (feature_id);


--
-- Name: analysisfeature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisfeature_idx2 ON chado.analysisfeature USING btree (analysis_id);


--
-- Name: analysisfeatureprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisfeatureprop_idx1 ON chado.analysisfeatureprop USING btree (analysisfeature_id);


--
-- Name: analysisfeatureprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisfeatureprop_idx2 ON chado.analysisfeatureprop USING btree (type_id);


--
-- Name: analysisprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisprop_idx1 ON chado.analysisprop USING btree (analysis_id);


--
-- Name: analysisprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX analysisprop_idx2 ON chado.analysisprop USING btree (type_id);


--
-- Name: arraydesign_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesign_idx1 ON chado.arraydesign USING btree (manufacturer_id);


--
-- Name: arraydesign_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesign_idx2 ON chado.arraydesign USING btree (platformtype_id);


--
-- Name: arraydesign_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesign_idx3 ON chado.arraydesign USING btree (substratetype_id);


--
-- Name: arraydesign_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesign_idx4 ON chado.arraydesign USING btree (protocol_id);


--
-- Name: arraydesign_idx5; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesign_idx5 ON chado.arraydesign USING btree (dbxref_id);


--
-- Name: arraydesignprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesignprop_idx1 ON chado.arraydesignprop USING btree (arraydesign_id);


--
-- Name: arraydesignprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX arraydesignprop_idx2 ON chado.arraydesignprop USING btree (type_id);


--
-- Name: assay_biomaterial_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_biomaterial_idx1 ON chado.assay_biomaterial USING btree (assay_id);


--
-- Name: assay_biomaterial_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_biomaterial_idx2 ON chado.assay_biomaterial USING btree (biomaterial_id);


--
-- Name: assay_biomaterial_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_biomaterial_idx3 ON chado.assay_biomaterial USING btree (channel_id);


--
-- Name: assay_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_idx1 ON chado.assay USING btree (arraydesign_id);


--
-- Name: assay_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_idx2 ON chado.assay USING btree (protocol_id);


--
-- Name: assay_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_idx3 ON chado.assay USING btree (operator_id);


--
-- Name: assay_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_idx4 ON chado.assay USING btree (dbxref_id);


--
-- Name: assay_project_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_project_idx1 ON chado.assay_project USING btree (assay_id);


--
-- Name: assay_project_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assay_project_idx2 ON chado.assay_project USING btree (project_id);


--
-- Name: assayprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assayprop_idx1 ON chado.assayprop USING btree (assay_id);


--
-- Name: assayprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX assayprop_idx2 ON chado.assayprop USING btree (type_id);


--
-- Name: binloc_boxrange; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX binloc_boxrange ON chado.featureloc USING gist (chado.boxrange(fmin, fmax));


--
-- Name: binloc_boxrange_src; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX binloc_boxrange_src ON chado.featureloc USING gist (chado.boxrange(srcfeature_id, fmin, fmax));


--
-- Name: biomaterial_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_dbxref_idx1 ON chado.biomaterial_dbxref USING btree (biomaterial_id);


--
-- Name: biomaterial_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_dbxref_idx2 ON chado.biomaterial_dbxref USING btree (dbxref_id);


--
-- Name: biomaterial_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_idx1 ON chado.biomaterial USING btree (taxon_id);


--
-- Name: biomaterial_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_idx2 ON chado.biomaterial USING btree (biosourceprovider_id);


--
-- Name: biomaterial_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_idx3 ON chado.biomaterial USING btree (dbxref_id);


--
-- Name: biomaterial_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_relationship_idx1 ON chado.biomaterial_relationship USING btree (subject_id);


--
-- Name: biomaterial_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_relationship_idx2 ON chado.biomaterial_relationship USING btree (object_id);


--
-- Name: biomaterial_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_relationship_idx3 ON chado.biomaterial_relationship USING btree (type_id);


--
-- Name: biomaterial_treatment_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_treatment_idx1 ON chado.biomaterial_treatment USING btree (biomaterial_id);


--
-- Name: biomaterial_treatment_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_treatment_idx2 ON chado.biomaterial_treatment USING btree (treatment_id);


--
-- Name: biomaterial_treatment_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterial_treatment_idx3 ON chado.biomaterial_treatment USING btree (unittype_id);


--
-- Name: biomaterialprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterialprop_idx1 ON chado.biomaterialprop USING btree (biomaterial_id);


--
-- Name: biomaterialprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX biomaterialprop_idx2 ON chado.biomaterialprop USING btree (type_id);


--
-- Name: blast_hit_data_analysis_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_analysis_id_idx ON chado.blast_hit_data USING btree (analysis_id);


--
-- Name: blast_hit_data_analysisfeature_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_analysisfeature_id_idx ON chado.blast_hit_data USING btree (analysisfeature_id);


--
-- Name: blast_hit_data_blast_org_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_blast_org_id_idx ON chado.blast_hit_data USING btree (blast_org_id);


--
-- Name: blast_hit_data_db_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_db_id_idx ON chado.blast_hit_data USING btree (db_id);


--
-- Name: blast_hit_data_feature_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_feature_id_idx ON chado.blast_hit_data USING btree (feature_id);


--
-- Name: blast_hit_data_hit_accession_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_hit_accession_idx ON chado.blast_hit_data USING btree (hit_accession);


--
-- Name: blast_hit_data_hit_best_eval_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_hit_best_eval_idx ON chado.blast_hit_data USING btree (hit_best_eval);


--
-- Name: blast_hit_data_hit_name_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_hit_name_idx ON chado.blast_hit_data USING btree (hit_organism);


--
-- Name: blast_hit_data_hit_organism_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_hit_data_hit_organism_idx ON chado.blast_hit_data USING btree (hit_organism);


--
-- Name: blast_organisms_blast_org_name_idx_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX blast_organisms_blast_org_name_idx_idx ON chado.blast_organisms USING btree (blast_org_name);


--
-- Name: chado_gene_gene_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX chado_gene_gene_id_idx ON chado.chado_gene USING btree (gene_id);


--
-- Name: contact_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contact_relationship_idx1 ON chado.contact_relationship USING btree (type_id);


--
-- Name: contact_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contact_relationship_idx2 ON chado.contact_relationship USING btree (subject_id);


--
-- Name: contact_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contact_relationship_idx3 ON chado.contact_relationship USING btree (object_id);


--
-- Name: contactprop_contactprop_idx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contactprop_contactprop_idx1_idx ON chado.contactprop USING btree (contact_id);


--
-- Name: contactprop_contactprop_idx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contactprop_contactprop_idx2_idx ON chado.contactprop USING btree (type_id);


--
-- Name: contactprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contactprop_idx1 ON chado.contactprop USING btree (contact_id);


--
-- Name: contactprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX contactprop_idx2 ON chado.contactprop USING btree (type_id);


--
-- Name: control_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX control_idx1 ON chado.control USING btree (type_id);


--
-- Name: control_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX control_idx2 ON chado.control USING btree (assay_id);


--
-- Name: control_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX control_idx3 ON chado.control USING btree (tableinfo_id);


--
-- Name: control_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX control_idx4 ON chado.control USING btree (row_id);


--
-- Name: INDEX cvterm_c1; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON INDEX chado.cvterm_c1 IS 'A name can mean different things in
different contexts; for example "chromosome" in SO and GO. A name
should be unique within an ontology or cv. A name may exist twice in a
cv, in both obsolete and non-obsolete forms - these will be for
different cvterms with different OBO identifiers; so GO documentation
for more details on obsoletion. Note that occasionally multiple
obsolete terms with the same name will exist in the same cv. If this
is a possibility for the ontology under consideration (e.g. GO) then the
ID should be appended to the name to ensure uniqueness.';


--
-- Name: INDEX cvterm_c2; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON INDEX chado.cvterm_c2 IS 'The OBO identifier is globally unique.';


--
-- Name: cvterm_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_dbxref_idx1 ON chado.cvterm_dbxref USING btree (cvterm_id);


--
-- Name: cvterm_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_dbxref_idx2 ON chado.cvterm_dbxref USING btree (dbxref_id);


--
-- Name: cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_idx1 ON chado.cvterm USING btree (cv_id);


--
-- Name: cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_idx2 ON chado.cvterm USING btree (name);


--
-- Name: cvterm_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_idx3 ON chado.cvterm USING btree (dbxref_id);


--
-- Name: cvterm_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_relationship_idx1 ON chado.cvterm_relationship USING btree (type_id);


--
-- Name: cvterm_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_relationship_idx2 ON chado.cvterm_relationship USING btree (subject_id);


--
-- Name: cvterm_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvterm_relationship_idx3 ON chado.cvterm_relationship USING btree (object_id);


--
-- Name: cvtermpath_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermpath_idx1 ON chado.cvtermpath USING btree (type_id);


--
-- Name: cvtermpath_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermpath_idx2 ON chado.cvtermpath USING btree (subject_id);


--
-- Name: cvtermpath_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermpath_idx3 ON chado.cvtermpath USING btree (object_id);


--
-- Name: cvtermpath_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermpath_idx4 ON chado.cvtermpath USING btree (cv_id);


--
-- Name: cvtermprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermprop_idx1 ON chado.cvtermprop USING btree (cvterm_id);


--
-- Name: cvtermprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermprop_idx2 ON chado.cvtermprop USING btree (type_id);


--
-- Name: cvtermsynonym_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX cvtermsynonym_idx1 ON chado.cvtermsynonym USING btree (cvterm_id);


--
-- Name: dbprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbprop_idx1 ON chado.dbprop USING btree (db_id);


--
-- Name: dbprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbprop_idx2 ON chado.dbprop USING btree (type_id);


--
-- Name: dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbxref_idx1 ON chado.dbxref USING btree (db_id);


--
-- Name: dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbxref_idx2 ON chado.dbxref USING btree (accession);


--
-- Name: dbxref_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbxref_idx3 ON chado.dbxref USING btree (version);


--
-- Name: dbxrefprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbxrefprop_idx1 ON chado.dbxrefprop USING btree (dbxref_id);


--
-- Name: dbxrefprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX dbxrefprop_idx2 ON chado.dbxrefprop USING btree (type_id);


--
-- Name: element_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_idx1 ON chado.element USING btree (feature_id);


--
-- Name: element_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_idx2 ON chado.element USING btree (arraydesign_id);


--
-- Name: element_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_idx3 ON chado.element USING btree (type_id);


--
-- Name: element_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_idx4 ON chado.element USING btree (dbxref_id);


--
-- Name: element_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_relationship_idx1 ON chado.element_relationship USING btree (subject_id);


--
-- Name: element_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_relationship_idx2 ON chado.element_relationship USING btree (type_id);


--
-- Name: element_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_relationship_idx3 ON chado.element_relationship USING btree (object_id);


--
-- Name: element_relationship_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX element_relationship_idx4 ON chado.element_relationship USING btree (value);


--
-- Name: elementresult_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_idx1 ON chado.elementresult USING btree (element_id);


--
-- Name: elementresult_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_idx2 ON chado.elementresult USING btree (quantification_id);


--
-- Name: elementresult_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_idx3 ON chado.elementresult USING btree (signal);


--
-- Name: elementresult_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_relationship_idx1 ON chado.elementresult_relationship USING btree (subject_id);


--
-- Name: elementresult_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_relationship_idx2 ON chado.elementresult_relationship USING btree (type_id);


--
-- Name: elementresult_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_relationship_idx3 ON chado.elementresult_relationship USING btree (object_id);


--
-- Name: elementresult_relationship_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX elementresult_relationship_idx4 ON chado.elementresult_relationship USING btree (value);


--
-- Name: environment_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX environment_cvterm_idx1 ON chado.environment_cvterm USING btree (environment_id);


--
-- Name: environment_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX environment_cvterm_idx2 ON chado.environment_cvterm USING btree (cvterm_id);


--
-- Name: environment_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX environment_idx1 ON chado.environment USING btree (uniquename);


--
-- Name: expression_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_cvterm_idx1 ON chado.expression_cvterm USING btree (expression_id);


--
-- Name: expression_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_cvterm_idx2 ON chado.expression_cvterm USING btree (cvterm_id);


--
-- Name: expression_cvterm_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_cvterm_idx3 ON chado.expression_cvterm USING btree (cvterm_type_id);


--
-- Name: expression_cvtermprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_cvtermprop_idx1 ON chado.expression_cvtermprop USING btree (expression_cvterm_id);


--
-- Name: expression_cvtermprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_cvtermprop_idx2 ON chado.expression_cvtermprop USING btree (type_id);


--
-- Name: expression_image_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_image_idx1 ON chado.expression_image USING btree (expression_id);


--
-- Name: expression_image_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_image_idx2 ON chado.expression_image USING btree (eimage_id);


--
-- Name: expression_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_pub_idx1 ON chado.expression_pub USING btree (expression_id);


--
-- Name: expression_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expression_pub_idx2 ON chado.expression_pub USING btree (pub_id);


--
-- Name: expressionprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expressionprop_idx1 ON chado.expressionprop USING btree (expression_id);


--
-- Name: expressionprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX expressionprop_idx2 ON chado.expressionprop USING btree (type_id);


--
-- Name: feature_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_contact_idx1 ON chado.feature_contact USING btree (feature_id);


--
-- Name: feature_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_contact_idx2 ON chado.feature_contact USING btree (contact_id);


--
-- Name: feature_cvterm_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_dbxref_idx1 ON chado.feature_cvterm_dbxref USING btree (feature_cvterm_id);


--
-- Name: feature_cvterm_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_dbxref_idx2 ON chado.feature_cvterm_dbxref USING btree (dbxref_id);


--
-- Name: feature_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_idx1 ON chado.feature_cvterm USING btree (feature_id);


--
-- Name: feature_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_idx2 ON chado.feature_cvterm USING btree (cvterm_id);


--
-- Name: feature_cvterm_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_idx3 ON chado.feature_cvterm USING btree (pub_id);


--
-- Name: feature_cvterm_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_pub_idx1 ON chado.feature_cvterm_pub USING btree (feature_cvterm_id);


--
-- Name: feature_cvterm_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvterm_pub_idx2 ON chado.feature_cvterm_pub USING btree (pub_id);


--
-- Name: feature_cvtermprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvtermprop_idx1 ON chado.feature_cvtermprop USING btree (feature_cvterm_id);


--
-- Name: feature_cvtermprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_cvtermprop_idx2 ON chado.feature_cvtermprop USING btree (type_id);


--
-- Name: feature_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_dbxref_idx1 ON chado.feature_dbxref USING btree (feature_id);


--
-- Name: feature_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_dbxref_idx2 ON chado.feature_dbxref USING btree (dbxref_id);


--
-- Name: feature_expression_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_expression_idx1 ON chado.feature_expression USING btree (expression_id);


--
-- Name: feature_expression_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_expression_idx2 ON chado.feature_expression USING btree (feature_id);


--
-- Name: feature_expression_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_expression_idx3 ON chado.feature_expression USING btree (pub_id);


--
-- Name: feature_expressionprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_expressionprop_idx1 ON chado.feature_expressionprop USING btree (feature_expression_id);


--
-- Name: feature_expressionprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_expressionprop_idx2 ON chado.feature_expressionprop USING btree (type_id);


--
-- Name: feature_genotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_genotype_idx1 ON chado.feature_genotype USING btree (feature_id);


--
-- Name: feature_genotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_genotype_idx2 ON chado.feature_genotype USING btree (genotype_id);


--
-- Name: feature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx1 ON chado.feature USING btree (dbxref_id);


--
-- Name: feature_idx1b; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx1b ON chado.feature USING btree (feature_id, dbxref_id) WHERE (dbxref_id IS NOT NULL);


--
-- Name: feature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx2 ON chado.feature USING btree (organism_id);


--
-- Name: feature_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx3 ON chado.feature USING btree (type_id);


--
-- Name: feature_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx4 ON chado.feature USING btree (uniquename);


--
-- Name: feature_idx5; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_idx5 ON chado.feature USING btree (lower((name)::text));


--
-- Name: feature_name_ind1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_name_ind1 ON chado.feature USING btree (name);


--
-- Name: feature_phenotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_phenotype_idx1 ON chado.feature_phenotype USING btree (feature_id);


--
-- Name: feature_phenotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_phenotype_idx2 ON chado.feature_phenotype USING btree (phenotype_id);


--
-- Name: feature_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_pub_idx1 ON chado.feature_pub USING btree (feature_id);


--
-- Name: feature_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_pub_idx2 ON chado.feature_pub USING btree (pub_id);


--
-- Name: feature_pubprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_pubprop_idx1 ON chado.feature_pubprop USING btree (feature_pub_id);


--
-- Name: feature_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_idx1 ON chado.feature_relationship USING btree (subject_id);


--
-- Name: feature_relationship_idx1b; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_idx1b ON chado.feature_relationship USING btree (object_id, subject_id, type_id);


--
-- Name: feature_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_idx2 ON chado.feature_relationship USING btree (object_id);


--
-- Name: feature_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_idx3 ON chado.feature_relationship USING btree (type_id);


--
-- Name: feature_relationship_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_pub_idx1 ON chado.feature_relationship_pub USING btree (feature_relationship_id);


--
-- Name: feature_relationship_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationship_pub_idx2 ON chado.feature_relationship_pub USING btree (pub_id);


--
-- Name: feature_relationshipprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationshipprop_idx1 ON chado.feature_relationshipprop USING btree (feature_relationship_id);


--
-- Name: feature_relationshipprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationshipprop_idx2 ON chado.feature_relationshipprop USING btree (type_id);


--
-- Name: feature_relationshipprop_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationshipprop_pub_idx1 ON chado.feature_relationshipprop_pub USING btree (feature_relationshipprop_id);


--
-- Name: feature_relationshipprop_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_relationshipprop_pub_idx2 ON chado.feature_relationshipprop_pub USING btree (pub_id);


--
-- Name: feature_synonym_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_synonym_idx1 ON chado.feature_synonym USING btree (synonym_id);


--
-- Name: feature_synonym_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_synonym_idx2 ON chado.feature_synonym USING btree (feature_id);


--
-- Name: feature_synonym_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX feature_synonym_idx3 ON chado.feature_synonym USING btree (pub_id);


--
-- Name: featureloc_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_idx1 ON chado.featureloc USING btree (feature_id);


--
-- Name: featureloc_idx1b; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_idx1b ON chado.featureloc USING btree (feature_id, fmin, fmax);


--
-- Name: featureloc_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_idx2 ON chado.featureloc USING btree (srcfeature_id);


--
-- Name: featureloc_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_idx3 ON chado.featureloc USING btree (srcfeature_id, fmin, fmax);


--
-- Name: featureloc_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_pub_idx1 ON chado.featureloc_pub USING btree (featureloc_id);


--
-- Name: featureloc_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureloc_pub_idx2 ON chado.featureloc_pub USING btree (pub_id);


--
-- Name: featuremap_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_contact_idx1 ON chado.featuremap_contact USING btree (featuremap_id);


--
-- Name: featuremap_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_contact_idx2 ON chado.featuremap_contact USING btree (contact_id);


--
-- Name: featuremap_dbxref_featuremap_dbxref_idx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_dbxref_featuremap_dbxref_idx1_idx ON chado.featuremap_dbxref USING btree (featuremap_dbxref_id);


--
-- Name: featuremap_dbxref_featuremap_dbxref_idx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_dbxref_featuremap_dbxref_idx2_idx ON chado.featuremap_dbxref USING btree (dbxref_id);


--
-- Name: featuremap_organism_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_organism_idx1 ON chado.featuremap_organism USING btree (featuremap_id);


--
-- Name: featuremap_organism_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_organism_idx2 ON chado.featuremap_organism USING btree (organism_id);


--
-- Name: featuremap_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_pub_idx1 ON chado.featuremap_pub USING btree (featuremap_id);


--
-- Name: featuremap_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremap_pub_idx2 ON chado.featuremap_pub USING btree (pub_id);


--
-- Name: featuremapprop_featuremapprop_idx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremapprop_featuremapprop_idx1_idx ON chado.featuremapprop USING btree (featuremap_id);


--
-- Name: featuremapprop_featuremapprop_idx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremapprop_featuremapprop_idx2_idx ON chado.featuremapprop USING btree (type_id);


--
-- Name: featuremapprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremapprop_idx1 ON chado.featuremapprop USING btree (featuremap_id);


--
-- Name: featuremapprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featuremapprop_idx2 ON chado.featuremapprop USING btree (type_id);


--
-- Name: featurepos_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurepos_idx1 ON chado.featurepos USING btree (featuremap_id);


--
-- Name: featurepos_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurepos_idx2 ON chado.featurepos USING btree (feature_id);


--
-- Name: featurepos_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurepos_idx3 ON chado.featurepos USING btree (map_feature_id);


--
-- Name: featureposprop_featureposprop_c1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureposprop_featureposprop_c1_idx ON chado.featureposprop USING btree (featurepos_id);


--
-- Name: featureposprop_featureposprop_idx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureposprop_featureposprop_idx2_idx ON chado.featureposprop USING btree (type_id);


--
-- Name: featureposprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureposprop_idx1 ON chado.featureposprop USING btree (featurepos_id);


--
-- Name: featureposprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureposprop_idx2 ON chado.featureposprop USING btree (type_id);


--
-- Name: INDEX featureprop_c1; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON INDEX chado.featureprop_c1 IS 'For any one feature, multivalued
property-value pairs must be differentiated by rank.';


--
-- Name: featureprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureprop_idx1 ON chado.featureprop USING btree (feature_id);


--
-- Name: featureprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureprop_idx2 ON chado.featureprop USING btree (type_id);


--
-- Name: featureprop_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureprop_pub_idx1 ON chado.featureprop_pub USING btree (featureprop_id);


--
-- Name: featureprop_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featureprop_pub_idx2 ON chado.featureprop_pub USING btree (pub_id);


--
-- Name: featurerange_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx1 ON chado.featurerange USING btree (featuremap_id);


--
-- Name: featurerange_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx2 ON chado.featurerange USING btree (feature_id);


--
-- Name: featurerange_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx3 ON chado.featurerange USING btree (leftstartf_id);


--
-- Name: featurerange_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx4 ON chado.featurerange USING btree (leftendf_id);


--
-- Name: featurerange_idx5; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx5 ON chado.featurerange USING btree (rightstartf_id);


--
-- Name: featurerange_idx6; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX featurerange_idx6 ON chado.featurerange USING btree (rightendf_id);


--
-- Name: gene2domain_g2d_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX gene2domain_g2d_indx0_idx ON chado.gene2domain USING btree (gene_id);


--
-- Name: gene_gene_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX gene_gene_indx0_idx ON chado.gene USING btree (abbreviation);


--
-- Name: gene_gene_indx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX gene_gene_indx1_idx ON chado.gene USING btree (nid);


--
-- Name: gene_gene_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX gene_gene_indx2_idx ON chado.gene USING btree (name);


--
-- Name: genome_metadata_QTL_search_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "genome_metadata_QTL_search_indx0_idx" ON chado.genome_metadata USING btree (project_id);


--
-- Name: genotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX genotype_idx1 ON chado.genotype USING btree (uniquename);


--
-- Name: genotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX genotype_idx2 ON chado.genotype USING btree (name);


--
-- Name: genotypeprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX genotypeprop_idx1 ON chado.genotypeprop USING btree (genotype_id);


--
-- Name: genotypeprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX genotypeprop_idx2 ON chado.genotypeprop USING btree (type_id);


--
-- Name: idx_cv_root_mview_cv_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_cv_root_mview_cv_id ON chado.cv_root_mview USING btree (cv_id);


--
-- Name: idx_cv_root_mview_cvterm_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_cv_root_mview_cvterm_id ON chado.cv_root_mview USING btree (cvterm_id);


--
-- Name: idx_library_feature_count_library_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_library_feature_count_library_id ON chado.library_feature_count USING btree (library_id);


--
-- Name: idx_organism_feature_count_cvterm_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_organism_feature_count_cvterm_id ON chado.organism_feature_count USING btree (cvterm_id);


--
-- Name: idx_organism_feature_count_feature_type; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_organism_feature_count_feature_type ON chado.organism_feature_count USING btree (feature_type);


--
-- Name: idx_organism_feature_count_organism_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX idx_organism_feature_count_organism_id ON chado.organism_feature_count USING btree (organism_id);


--
-- Name: library_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_contact_idx1 ON chado.library USING btree (library_id);


--
-- Name: library_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_contact_idx2 ON chado.contact USING btree (contact_id);


--
-- Name: library_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_cvterm_idx1 ON chado.library_cvterm USING btree (library_id);


--
-- Name: library_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_cvterm_idx2 ON chado.library_cvterm USING btree (cvterm_id);


--
-- Name: library_cvterm_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_cvterm_idx3 ON chado.library_cvterm USING btree (pub_id);


--
-- Name: library_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_dbxref_idx1 ON chado.library_dbxref USING btree (library_id);


--
-- Name: library_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_dbxref_idx2 ON chado.library_dbxref USING btree (dbxref_id);


--
-- Name: library_expression_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_expression_idx1 ON chado.library_expression USING btree (library_id);


--
-- Name: library_expression_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_expression_idx2 ON chado.library_expression USING btree (expression_id);


--
-- Name: library_expression_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_expression_idx3 ON chado.library_expression USING btree (pub_id);


--
-- Name: library_expressionprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_expressionprop_idx1 ON chado.library_expressionprop USING btree (library_expression_id);


--
-- Name: library_expressionprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_expressionprop_idx2 ON chado.library_expressionprop USING btree (type_id);


--
-- Name: library_feature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_feature_idx1 ON chado.library_feature USING btree (library_id);


--
-- Name: library_feature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_feature_idx2 ON chado.library_feature USING btree (feature_id);


--
-- Name: library_featureprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_featureprop_idx1 ON chado.library_featureprop USING btree (library_feature_id);


--
-- Name: library_featureprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_featureprop_idx2 ON chado.library_featureprop USING btree (type_id);


--
-- Name: library_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_idx1 ON chado.library USING btree (organism_id);


--
-- Name: library_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_idx2 ON chado.library USING btree (type_id);


--
-- Name: library_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_idx3 ON chado.library USING btree (uniquename);


--
-- Name: library_name_ind1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_name_ind1 ON chado.library USING btree (name);


--
-- Name: library_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_pub_idx1 ON chado.library_pub USING btree (library_id);


--
-- Name: library_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_pub_idx2 ON chado.library_pub USING btree (pub_id);


--
-- Name: library_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_relationship_idx1 ON chado.library_relationship USING btree (subject_id);


--
-- Name: library_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_relationship_idx2 ON chado.library_relationship USING btree (object_id);


--
-- Name: library_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_relationship_idx3 ON chado.library_relationship USING btree (type_id);


--
-- Name: library_relationship_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_relationship_pub_idx1 ON chado.library_relationship_pub USING btree (library_relationship_id);


--
-- Name: library_relationship_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_relationship_pub_idx2 ON chado.library_relationship_pub USING btree (pub_id);


--
-- Name: library_synonym_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_synonym_idx1 ON chado.library_synonym USING btree (synonym_id);


--
-- Name: library_synonym_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_synonym_idx2 ON chado.library_synonym USING btree (library_id);


--
-- Name: library_synonym_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX library_synonym_idx3 ON chado.library_synonym USING btree (pub_id);


--
-- Name: libraryprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX libraryprop_idx1 ON chado.libraryprop USING btree (library_id);


--
-- Name: libraryprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX libraryprop_idx2 ON chado.libraryprop USING btree (type_id);


--
-- Name: libraryprop_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX libraryprop_pub_idx1 ON chado.libraryprop_pub USING btree (libraryprop_id);


--
-- Name: libraryprop_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX libraryprop_pub_idx2 ON chado.libraryprop_pub USING btree (pub_id);


--
-- Name: magedocumentation_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX magedocumentation_idx1 ON chado.magedocumentation USING btree (mageml_id);


--
-- Name: magedocumentation_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX magedocumentation_idx2 ON chado.magedocumentation USING btree (tableinfo_id);


--
-- Name: magedocumentation_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX magedocumentation_idx3 ON chado.magedocumentation USING btree (row_id);


--
-- Name: marker_search_QTL_search_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "marker_search_QTL_search_indx0_idx" ON chado.marker_search USING btree (organism);


--
-- Name: marker_search_QTL_search_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "marker_search_QTL_search_indx2_idx" ON chado.marker_search USING btree (cmarker);


--
-- Name: nd_experiment_analysis_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_analysis_idx1 ON chado.nd_experiment_analysis USING btree (nd_experiment_id);


--
-- Name: nd_experiment_analysis_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_analysis_idx2 ON chado.nd_experiment_analysis USING btree (analysis_id);


--
-- Name: nd_experiment_analysis_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_analysis_idx3 ON chado.nd_experiment_analysis USING btree (type_id);


--
-- Name: nd_experiment_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_contact_idx1 ON chado.nd_experiment_contact USING btree (nd_experiment_id);


--
-- Name: nd_experiment_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_contact_idx2 ON chado.nd_experiment_contact USING btree (contact_id);


--
-- Name: nd_experiment_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_dbxref_idx1 ON chado.nd_experiment_dbxref USING btree (nd_experiment_id);


--
-- Name: nd_experiment_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_dbxref_idx2 ON chado.nd_experiment_dbxref USING btree (dbxref_id);


--
-- Name: nd_experiment_genotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_genotype_idx1 ON chado.nd_experiment_genotype USING btree (nd_experiment_id);


--
-- Name: nd_experiment_genotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_genotype_idx2 ON chado.nd_experiment_genotype USING btree (genotype_id);


--
-- Name: nd_experiment_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_idx1 ON chado.nd_experiment USING btree (nd_geolocation_id);


--
-- Name: nd_experiment_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_idx2 ON chado.nd_experiment USING btree (type_id);


--
-- Name: nd_experiment_phenotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_phenotype_idx1 ON chado.nd_experiment_phenotype USING btree (nd_experiment_id);


--
-- Name: nd_experiment_phenotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_phenotype_idx2 ON chado.nd_experiment_phenotype USING btree (phenotype_id);


--
-- Name: nd_experiment_project_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_project_idx1 ON chado.nd_experiment_project USING btree (project_id);


--
-- Name: nd_experiment_project_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_project_idx2 ON chado.nd_experiment_project USING btree (nd_experiment_id);


--
-- Name: nd_experiment_protocol_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_protocol_idx1 ON chado.nd_experiment_protocol USING btree (nd_experiment_id);


--
-- Name: nd_experiment_protocol_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_protocol_idx2 ON chado.nd_experiment_protocol USING btree (nd_protocol_id);


--
-- Name: nd_experiment_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_pub_idx1 ON chado.nd_experiment_pub USING btree (nd_experiment_id);


--
-- Name: nd_experiment_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_pub_idx2 ON chado.nd_experiment_pub USING btree (pub_id);


--
-- Name: nd_experiment_stock_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stock_dbxref_idx1 ON chado.nd_experiment_stock_dbxref USING btree (nd_experiment_stock_id);


--
-- Name: nd_experiment_stock_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stock_dbxref_idx2 ON chado.nd_experiment_stock_dbxref USING btree (dbxref_id);


--
-- Name: nd_experiment_stock_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stock_idx1 ON chado.nd_experiment_stock USING btree (nd_experiment_id);


--
-- Name: nd_experiment_stock_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stock_idx2 ON chado.nd_experiment_stock USING btree (stock_id);


--
-- Name: nd_experiment_stock_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stock_idx3 ON chado.nd_experiment_stock USING btree (type_id);


--
-- Name: nd_experiment_stockprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stockprop_idx1 ON chado.nd_experiment_stockprop USING btree (nd_experiment_stock_id);


--
-- Name: nd_experiment_stockprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experiment_stockprop_idx2 ON chado.nd_experiment_stockprop USING btree (type_id);


--
-- Name: nd_experimentprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experimentprop_idx1 ON chado.nd_experimentprop USING btree (nd_experiment_id);


--
-- Name: nd_experimentprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_experimentprop_idx2 ON chado.nd_experimentprop USING btree (type_id);


--
-- Name: nd_geolocation_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_geolocation_idx1 ON chado.nd_geolocation USING btree (latitude);


--
-- Name: nd_geolocation_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_geolocation_idx2 ON chado.nd_geolocation USING btree (longitude);


--
-- Name: nd_geolocation_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_geolocation_idx3 ON chado.nd_geolocation USING btree (altitude);


--
-- Name: nd_geolocationprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_geolocationprop_idx1 ON chado.nd_geolocationprop USING btree (nd_geolocation_id);


--
-- Name: nd_geolocationprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_geolocationprop_idx2 ON chado.nd_geolocationprop USING btree (type_id);


--
-- Name: nd_protocol_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocol_idx1 ON chado.nd_protocol USING btree (type_id);


--
-- Name: nd_protocol_reagent_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocol_reagent_idx1 ON chado.nd_protocol_reagent USING btree (nd_protocol_id);


--
-- Name: nd_protocol_reagent_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocol_reagent_idx2 ON chado.nd_protocol_reagent USING btree (reagent_id);


--
-- Name: nd_protocol_reagent_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocol_reagent_idx3 ON chado.nd_protocol_reagent USING btree (type_id);


--
-- Name: nd_protocolprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocolprop_idx1 ON chado.nd_protocolprop USING btree (nd_protocol_id);


--
-- Name: nd_protocolprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_protocolprop_idx2 ON chado.nd_protocolprop USING btree (type_id);


--
-- Name: nd_reagent_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagent_idx1 ON chado.nd_reagent USING btree (type_id);


--
-- Name: nd_reagent_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagent_idx2 ON chado.nd_reagent USING btree (feature_id);


--
-- Name: nd_reagent_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagent_relationship_idx1 ON chado.nd_reagent_relationship USING btree (subject_reagent_id);


--
-- Name: nd_reagent_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagent_relationship_idx2 ON chado.nd_reagent_relationship USING btree (object_reagent_id);


--
-- Name: nd_reagent_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagent_relationship_idx3 ON chado.nd_reagent_relationship USING btree (type_id);


--
-- Name: nd_reagentprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagentprop_idx1 ON chado.nd_reagentprop USING btree (nd_reagent_id);


--
-- Name: nd_reagentprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX nd_reagentprop_idx2 ON chado.nd_reagentprop USING btree (type_id);


--
-- Name: organism_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_cvterm_idx1 ON chado.organism_cvterm USING btree (organism_id);


--
-- Name: organism_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_cvterm_idx2 ON chado.organism_cvterm USING btree (cvterm_id);


--
-- Name: organism_cvtermprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_cvtermprop_idx1 ON chado.organism_cvtermprop USING btree (organism_cvterm_id);


--
-- Name: organism_cvtermprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_cvtermprop_idx2 ON chado.organism_cvtermprop USING btree (type_id);


--
-- Name: organism_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_dbxref_idx1 ON chado.organism_dbxref USING btree (organism_id);


--
-- Name: organism_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_dbxref_idx2 ON chado.organism_dbxref USING btree (dbxref_id);


--
-- Name: organism_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_pub_idx1 ON chado.organism_pub USING btree (organism_id);


--
-- Name: organism_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_pub_idx2 ON chado.organism_pub USING btree (pub_id);


--
-- Name: organism_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_relationship_idx1 ON chado.organism_relationship USING btree (subject_id);


--
-- Name: organism_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_relationship_idx2 ON chado.organism_relationship USING btree (object_id);


--
-- Name: organism_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organism_relationship_idx3 ON chado.organism_relationship USING btree (type_id);


--
-- Name: organismprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organismprop_idx1 ON chado.organismprop USING btree (organism_id);


--
-- Name: organismprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organismprop_idx2 ON chado.organismprop USING btree (type_id);


--
-- Name: organismprop_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organismprop_pub_idx1 ON chado.organismprop_pub USING btree (organismprop_id);


--
-- Name: organismprop_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX organismprop_pub_idx2 ON chado.organismprop_pub USING btree (pub_id);


--
-- Name: phendesc_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phendesc_idx1 ON chado.phendesc USING btree (genotype_id);


--
-- Name: phendesc_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phendesc_idx2 ON chado.phendesc USING btree (environment_id);


--
-- Name: phendesc_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phendesc_idx3 ON chado.phendesc USING btree (pub_id);


--
-- Name: phenotype_comparison_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_comparison_cvterm_idx1 ON chado.phenotype_comparison_cvterm USING btree (phenotype_comparison_id);


--
-- Name: phenotype_comparison_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_comparison_cvterm_idx2 ON chado.phenotype_comparison_cvterm USING btree (cvterm_id);


--
-- Name: phenotype_comparison_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_comparison_idx1 ON chado.phenotype_comparison USING btree (genotype1_id);


--
-- Name: phenotype_comparison_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_comparison_idx2 ON chado.phenotype_comparison USING btree (genotype2_id);


--
-- Name: phenotype_comparison_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_comparison_idx4 ON chado.phenotype_comparison USING btree (pub_id);


--
-- Name: phenotype_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_cvterm_idx1 ON chado.phenotype_cvterm USING btree (phenotype_id);


--
-- Name: phenotype_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_cvterm_idx2 ON chado.phenotype_cvterm USING btree (cvterm_id);


--
-- Name: phenotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_idx1 ON chado.phenotype USING btree (cvalue_id);


--
-- Name: phenotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_idx2 ON chado.phenotype USING btree (observable_id);


--
-- Name: phenotype_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotype_idx3 ON chado.phenotype USING btree (attr_id);


--
-- Name: phenotypeprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotypeprop_idx1 ON chado.phenotypeprop USING btree (phenotype_id);


--
-- Name: phenotypeprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenotypeprop_idx2 ON chado.phenotypeprop USING btree (type_id);


--
-- Name: phenstatement_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenstatement_idx1 ON chado.phenstatement USING btree (genotype_id);


--
-- Name: phenstatement_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phenstatement_idx2 ON chado.phenstatement USING btree (phenotype_id);


--
-- Name: phylonode_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_dbxref_idx1 ON chado.phylonode_dbxref USING btree (phylonode_id);


--
-- Name: phylonode_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_dbxref_idx2 ON chado.phylonode_dbxref USING btree (dbxref_id);


--
-- Name: phylonode_feature_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_feature_id_idx ON chado.phylonode USING btree (feature_id);


--
-- Name: phylonode_organism_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_organism_idx1 ON chado.phylonode_organism USING btree (phylonode_id);


--
-- Name: phylonode_organism_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_organism_idx2 ON chado.phylonode_organism USING btree (organism_id);


--
-- Name: phylonode_parent_phylonode_id_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_parent_phylonode_id_idx ON chado.phylonode USING btree (parent_phylonode_id);


--
-- Name: phylonode_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_pub_idx1 ON chado.phylonode_pub USING btree (phylonode_id);


--
-- Name: phylonode_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_pub_idx2 ON chado.phylonode_pub USING btree (pub_id);


--
-- Name: phylonode_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_relationship_idx1 ON chado.phylonode_relationship USING btree (subject_id);


--
-- Name: phylonode_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_relationship_idx2 ON chado.phylonode_relationship USING btree (object_id);


--
-- Name: phylonode_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonode_relationship_idx3 ON chado.phylonode_relationship USING btree (type_id);


--
-- Name: phylonodeprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonodeprop_idx1 ON chado.phylonodeprop USING btree (phylonode_id);


--
-- Name: phylonodeprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylonodeprop_idx2 ON chado.phylonodeprop USING btree (type_id);


--
-- Name: phylotree_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylotree_idx1 ON chado.phylotree USING btree (phylotree_id);


--
-- Name: phylotree_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylotree_pub_idx1 ON chado.phylotree_pub USING btree (phylotree_id);


--
-- Name: phylotree_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylotree_pub_idx2 ON chado.phylotree_pub USING btree (pub_id);


--
-- Name: INDEX phylotreeprop_c1; Type: COMMENT; Schema: chado; Owner: www
--

COMMENT ON INDEX chado.phylotreeprop_c1 IS 'For any one phylotree, multivalued
property-value pairs must be differentiated by rank.';


--
-- Name: phylotreeprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylotreeprop_idx1 ON chado.phylotreeprop USING btree (phylotree_id);


--
-- Name: phylotreeprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX phylotreeprop_idx2 ON chado.phylotreeprop USING btree (type_id);


--
-- Name: project_analysis_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_analysis_idx1 ON chado.project_analysis USING btree (project_id);


--
-- Name: project_analysis_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_analysis_idx2 ON chado.project_analysis USING btree (analysis_id);


--
-- Name: project_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_contact_idx1 ON chado.project_contact USING btree (project_id);


--
-- Name: project_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_contact_idx2 ON chado.project_contact USING btree (contact_id);


--
-- Name: project_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_dbxref_idx1 ON chado.project_dbxref USING btree (project_id);


--
-- Name: project_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_dbxref_idx2 ON chado.project_dbxref USING btree (dbxref_id);


--
-- Name: project_feature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_feature_idx1 ON chado.project_feature USING btree (feature_id);


--
-- Name: project_feature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_feature_idx2 ON chado.project_feature USING btree (project_id);


--
-- Name: project_phenotype_project_phenotype_indx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_phenotype_project_phenotype_indx1_idx ON chado.project_phenotype USING btree (project_id);


--
-- Name: project_phenotype_project_phenotype_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_phenotype_project_phenotype_indx2_idx ON chado.project_phenotype USING btree (phenotype_id);


--
-- Name: project_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_pub_idx1 ON chado.project_pub USING btree (project_id);


--
-- Name: project_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_pub_idx2 ON chado.project_pub USING btree (pub_id);


--
-- Name: project_stock_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_stock_idx1 ON chado.project_stock USING btree (stock_id);


--
-- Name: project_stock_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX project_stock_idx2 ON chado.project_stock USING btree (project_id);


--
-- Name: protocol_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocol_idx1 ON chado.protocol USING btree (type_id);


--
-- Name: protocol_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocol_idx2 ON chado.protocol USING btree (pub_id);


--
-- Name: protocol_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocol_idx3 ON chado.protocol USING btree (dbxref_id);


--
-- Name: protocolparam_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocolparam_idx1 ON chado.protocolparam USING btree (protocol_id);


--
-- Name: protocolparam_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocolparam_idx2 ON chado.protocolparam USING btree (datatype_id);


--
-- Name: protocolparam_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX protocolparam_idx3 ON chado.protocolparam USING btree (unittype_id);


--
-- Name: pub_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_dbxref_idx1 ON chado.pub_dbxref USING btree (pub_id);


--
-- Name: pub_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_dbxref_idx2 ON chado.pub_dbxref USING btree (dbxref_id);


--
-- Name: pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_idx1 ON chado.pub USING btree (type_id);


--
-- Name: pub_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_relationship_idx1 ON chado.pub_relationship USING btree (subject_id);


--
-- Name: pub_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_relationship_idx2 ON chado.pub_relationship USING btree (object_id);


--
-- Name: pub_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pub_relationship_idx3 ON chado.pub_relationship USING btree (type_id);


--
-- Name: pubauthor_contact_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pubauthor_contact_idx1 ON chado.pubauthor USING btree (pubauthor_id);


--
-- Name: pubauthor_contact_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pubauthor_contact_idx2 ON chado.contact USING btree (contact_id);


--
-- Name: pubauthor_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pubauthor_idx2 ON chado.pubauthor USING btree (pub_id);


--
-- Name: pubprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pubprop_idx1 ON chado.pubprop USING btree (pub_id);


--
-- Name: pubprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX pubprop_idx2 ON chado.pubprop USING btree (type_id);


--
-- Name: qtl_map_position_QTL_search_indx3_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_map_position_QTL_search_indx3_idx" ON chado.qtl_map_position USING btree (qtl_symbol);


--
-- Name: qtl_search_QTL_search_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_search_QTL_search_indx0_idx" ON chado.qtl_search USING btree (organism);


--
-- Name: qtl_search_QTL_search_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_search_QTL_search_indx2_idx" ON chado.qtl_search USING btree (expt_qtl_symbol);


--
-- Name: qtl_search_QTL_search_indx3_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_search_QTL_search_indx3_idx" ON chado.qtl_search USING btree (qtl_symbol);


--
-- Name: qtl_search_QTL_search_indx4_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_search_QTL_search_indx4_idx" ON chado.qtl_search USING btree (trait_class);


--
-- Name: qtl_search_QTL_search_indx5_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX "qtl_search_QTL_search_indx5_idx" ON chado.qtl_search USING btree (obo_terms);


--
-- Name: quantification_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_idx1 ON chado.quantification USING btree (acquisition_id);


--
-- Name: quantification_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_idx2 ON chado.quantification USING btree (operator_id);


--
-- Name: quantification_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_idx3 ON chado.quantification USING btree (protocol_id);


--
-- Name: quantification_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_idx4 ON chado.quantification USING btree (analysis_id);


--
-- Name: quantification_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_relationship_idx1 ON chado.quantification_relationship USING btree (subject_id);


--
-- Name: quantification_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_relationship_idx2 ON chado.quantification_relationship USING btree (type_id);


--
-- Name: quantification_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantification_relationship_idx3 ON chado.quantification_relationship USING btree (object_id);


--
-- Name: quantificationprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantificationprop_idx1 ON chado.quantificationprop USING btree (quantification_id);


--
-- Name: quantificationprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX quantificationprop_idx2 ON chado.quantificationprop USING btree (type_id);


--
-- Name: stock_cvterm_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_cvterm_idx1 ON chado.stock_cvterm USING btree (stock_id);


--
-- Name: stock_cvterm_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_cvterm_idx2 ON chado.stock_cvterm USING btree (cvterm_id);


--
-- Name: stock_cvterm_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_cvterm_idx3 ON chado.stock_cvterm USING btree (pub_id);


--
-- Name: stock_cvtermprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_cvtermprop_idx1 ON chado.stock_cvtermprop USING btree (stock_cvterm_id);


--
-- Name: stock_cvtermprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_cvtermprop_idx2 ON chado.stock_cvtermprop USING btree (type_id);


--
-- Name: stock_dbxref_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_dbxref_idx1 ON chado.stock_dbxref USING btree (stock_id);


--
-- Name: stock_dbxref_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_dbxref_idx2 ON chado.stock_dbxref USING btree (dbxref_id);


--
-- Name: stock_dbxrefprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_dbxrefprop_idx1 ON chado.stock_dbxrefprop USING btree (stock_dbxref_id);


--
-- Name: stock_dbxrefprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_dbxrefprop_idx2 ON chado.stock_dbxrefprop USING btree (type_id);


--
-- Name: stock_eimage_featuremap_stock_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_eimage_featuremap_stock_indx2_idx ON chado.stock_eimage USING btree (stock_id);


--
-- Name: stock_eimage_stock_eimage_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_eimage_stock_eimage_indx0_idx ON chado.stock_eimage USING btree (eimage_id);


--
-- Name: stock_feature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_feature_idx1 ON chado.stock_feature USING btree (stock_feature_id);


--
-- Name: stock_feature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_feature_idx2 ON chado.stock_feature USING btree (feature_id);


--
-- Name: stock_feature_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_feature_idx3 ON chado.stock_feature USING btree (stock_id);


--
-- Name: stock_feature_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_feature_idx4 ON chado.stock_feature USING btree (type_id);


--
-- Name: stock_featuremap_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_featuremap_idx1 ON chado.stock_featuremap USING btree (featuremap_id);


--
-- Name: stock_featuremap_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_featuremap_idx2 ON chado.stock_featuremap USING btree (stock_id);


--
-- Name: stock_featuremap_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_featuremap_idx3 ON chado.stock_featuremap USING btree (type_id);


--
-- Name: stock_genotype_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_genotype_idx1 ON chado.stock_genotype USING btree (stock_id);


--
-- Name: stock_genotype_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_genotype_idx2 ON chado.stock_genotype USING btree (genotype_id);


--
-- Name: stock_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_idx1 ON chado.stock USING btree (dbxref_id);


--
-- Name: stock_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_idx2 ON chado.stock USING btree (organism_id);


--
-- Name: stock_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_idx3 ON chado.stock USING btree (type_id);


--
-- Name: stock_idx4; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_idx4 ON chado.stock USING btree (uniquename);


--
-- Name: stock_library_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_library_idx1 ON chado.stock_library USING btree (library_id);


--
-- Name: stock_library_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_library_idx2 ON chado.stock_library USING btree (stock_id);


--
-- Name: stock_name_ind1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_name_ind1 ON chado.stock USING btree (name);


--
-- Name: stock_phenotype_stock_phenotype_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_phenotype_stock_phenotype_indx0_idx ON chado.stock_phenotype USING btree (phenotype_id);


--
-- Name: stock_phenotype_stock_phenotype_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_phenotype_stock_phenotype_indx2_idx ON chado.stock_phenotype USING btree (stock_id);


--
-- Name: stock_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_pub_idx1 ON chado.stock_pub USING btree (stock_id);


--
-- Name: stock_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_pub_idx2 ON chado.stock_pub USING btree (pub_id);


--
-- Name: stock_relationship_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_relationship_idx1 ON chado.stock_relationship USING btree (subject_id);


--
-- Name: stock_relationship_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_relationship_idx2 ON chado.stock_relationship USING btree (object_id);


--
-- Name: stock_relationship_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_relationship_idx3 ON chado.stock_relationship USING btree (type_id);


--
-- Name: stock_relationship_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_relationship_pub_idx1 ON chado.stock_relationship_pub USING btree (stock_relationship_id);


--
-- Name: stock_relationship_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_relationship_pub_idx2 ON chado.stock_relationship_pub USING btree (pub_id);


--
-- Name: stock_search_stock_search_indx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_search_stock_search_indx0_idx ON chado.stock_search USING btree (common_name);


--
-- Name: stock_search_stock_search_indx1_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_search_stock_search_indx1_idx ON chado.stock_search USING btree (stocktype);


--
-- Name: stock_search_stock_search_indx2_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stock_search_stock_search_indx2_idx ON chado.stock_search USING btree (collection);


--
-- Name: stockcollection_db_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_db_idx1 ON chado.stockcollection_db USING btree (stockcollection_id);


--
-- Name: stockcollection_db_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_db_idx2 ON chado.stockcollection_db USING btree (db_id);


--
-- Name: stockcollection_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_idx1 ON chado.stockcollection USING btree (contact_id);


--
-- Name: stockcollection_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_idx2 ON chado.stockcollection USING btree (type_id);


--
-- Name: stockcollection_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_idx3 ON chado.stockcollection USING btree (uniquename);


--
-- Name: stockcollection_name_ind1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_name_ind1 ON chado.stockcollection USING btree (name);


--
-- Name: stockcollection_stock_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_stock_idx1 ON chado.stockcollection_stock USING btree (stockcollection_id);


--
-- Name: stockcollection_stock_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollection_stock_idx2 ON chado.stockcollection_stock USING btree (stock_id);


--
-- Name: stockcollectionprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollectionprop_idx1 ON chado.stockcollectionprop USING btree (stockcollection_id);


--
-- Name: stockcollectionprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockcollectionprop_idx2 ON chado.stockcollectionprop USING btree (type_id);


--
-- Name: stockprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockprop_idx1 ON chado.stockprop USING btree (stock_id);


--
-- Name: stockprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockprop_idx2 ON chado.stockprop USING btree (type_id);


--
-- Name: stockprop_pub_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockprop_pub_idx1 ON chado.stockprop_pub USING btree (stockprop_id);


--
-- Name: stockprop_pub_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX stockprop_pub_idx2 ON chado.stockprop_pub USING btree (pub_id);


--
-- Name: study_assay_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX study_assay_idx1 ON chado.study_assay USING btree (study_id);


--
-- Name: study_assay_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX study_assay_idx2 ON chado.study_assay USING btree (assay_id);


--
-- Name: study_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX study_idx1 ON chado.study USING btree (contact_id);


--
-- Name: study_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX study_idx2 ON chado.study USING btree (pub_id);


--
-- Name: study_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX study_idx3 ON chado.study USING btree (dbxref_id);


--
-- Name: studydesign_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studydesign_idx1 ON chado.studydesign USING btree (study_id);


--
-- Name: studydesignprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studydesignprop_idx1 ON chado.studydesignprop USING btree (studydesign_id);


--
-- Name: studydesignprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studydesignprop_idx2 ON chado.studydesignprop USING btree (type_id);


--
-- Name: studyfactor_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyfactor_idx1 ON chado.studyfactor USING btree (studydesign_id);


--
-- Name: studyfactor_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyfactor_idx2 ON chado.studyfactor USING btree (type_id);


--
-- Name: studyfactorvalue_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyfactorvalue_idx1 ON chado.studyfactorvalue USING btree (studyfactor_id);


--
-- Name: studyfactorvalue_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyfactorvalue_idx2 ON chado.studyfactorvalue USING btree (assay_id);


--
-- Name: studyprop_feature_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyprop_feature_idx1 ON chado.studyprop_feature USING btree (studyprop_id);


--
-- Name: studyprop_feature_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyprop_feature_idx2 ON chado.studyprop_feature USING btree (feature_id);


--
-- Name: studyprop_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyprop_idx1 ON chado.studyprop USING btree (study_id);


--
-- Name: studyprop_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX studyprop_idx2 ON chado.studyprop USING btree (type_id);


--
-- Name: synonym_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX synonym_idx1 ON chado.synonym USING btree (type_id);


--
-- Name: synonym_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX synonym_idx2 ON chado.synonym USING btree (lower((synonym_sgml)::text));


--
-- Name: tmp_cds_handler_fmax; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tmp_cds_handler_fmax ON chado.tmp_cds_handler USING btree (fmax);


--
-- Name: tmp_cds_handler_relationship_cds_row_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tmp_cds_handler_relationship_cds_row_id ON chado.tmp_cds_handler_relationship USING btree (cds_row_id);


--
-- Name: tmp_cds_handler_relationship_grandparent; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tmp_cds_handler_relationship_grandparent ON chado.tmp_cds_handler_relationship USING btree (grandparent_id);


--
-- Name: tmp_cds_handler_seq_id; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tmp_cds_handler_seq_id ON chado.tmp_cds_handler USING btree (seq_id);


--
-- Name: treatment_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX treatment_idx1 ON chado.treatment USING btree (biomaterial_id);


--
-- Name: treatment_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX treatment_idx2 ON chado.treatment USING btree (type_id);


--
-- Name: treatment_idx3; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX treatment_idx3 ON chado.treatment USING btree (protocol_id);


--
-- Name: tripal_gff_temp_idx0; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_gff_temp_idx0 ON chado.tripal_gff_temp USING btree (feature_id);


--
-- Name: tripal_gff_temp_idx1; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_gff_temp_idx1 ON chado.tripal_gff_temp USING btree (organism_id);


--
-- Name: tripal_gff_temp_idx2; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_gff_temp_idx2 ON chado.tripal_gff_temp USING btree (uniquename);


--
-- Name: tripal_gffcds_temp_tripal_gff_temp_idx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_gffcds_temp_tripal_gff_temp_idx0_idx ON chado.tripal_gffcds_temp USING btree (parent_id);


--
-- Name: tripal_gffprotein_temp_tripal_gff_temp_idx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_gffprotein_temp_tripal_gff_temp_idx0_idx ON chado.tripal_gffprotein_temp USING btree (parent_id);


--
-- Name: tripal_obo_temp_tripal_obo_temp_idx0_idx; Type: INDEX; Schema: chado; Owner: www
--

CREATE INDEX tripal_obo_temp_tripal_obo_temp_idx0_idx ON chado.tripal_obo_temp USING btree (type);


--
-- Name: acquisition_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition
    ADD CONSTRAINT acquisition_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisition_channel_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition
    ADD CONSTRAINT acquisition_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES chado.channel(channel_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisition_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition
    ADD CONSTRAINT acquisition_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisition_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship
    ADD CONSTRAINT acquisition_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.acquisition(acquisition_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisition_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship
    ADD CONSTRAINT acquisition_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.acquisition(acquisition_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisition_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisition_relationship
    ADD CONSTRAINT acquisition_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisitionprop_acquisition_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisitionprop
    ADD CONSTRAINT acquisitionprop_acquisition_id_fkey FOREIGN KEY (acquisition_id) REFERENCES chado.acquisition(acquisition_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: acquisitionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.acquisitionprop
    ADD CONSTRAINT acquisitionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_cvterm_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_cvterm
    ADD CONSTRAINT analysis_cvterm_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_cvterm
    ADD CONSTRAINT analysis_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_dbxref_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_dbxref
    ADD CONSTRAINT analysis_dbxref_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_dbxref
    ADD CONSTRAINT analysis_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_organism_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_organism
    ADD CONSTRAINT analysis_organism_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_organism_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_organism
    ADD CONSTRAINT analysis_organism_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_pub_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_pub
    ADD CONSTRAINT analysis_pub_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_pub
    ADD CONSTRAINT analysis_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship
    ADD CONSTRAINT analysis_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship
    ADD CONSTRAINT analysis_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysis_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysis_relationship
    ADD CONSTRAINT analysis_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisfeature_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeature
    ADD CONSTRAINT analysisfeature_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisfeature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeature
    ADD CONSTRAINT analysisfeature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisfeatureprop_analysisfeature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeatureprop
    ADD CONSTRAINT analysisfeatureprop_analysisfeature_id_fkey FOREIGN KEY (analysisfeature_id) REFERENCES chado.analysisfeature(analysisfeature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisfeatureprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisfeatureprop
    ADD CONSTRAINT analysisfeatureprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisprop_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisprop
    ADD CONSTRAINT analysisprop_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: analysisprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.analysisprop
    ADD CONSTRAINT analysisprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesign_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesign_manufacturer_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_manufacturer_id_fkey FOREIGN KEY (manufacturer_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesign_platformtype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_platformtype_id_fkey FOREIGN KEY (platformtype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesign_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesign_substratetype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesign
    ADD CONSTRAINT arraydesign_substratetype_id_fkey FOREIGN KEY (substratetype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesignprop_arraydesign_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesignprop
    ADD CONSTRAINT arraydesignprop_arraydesign_id_fkey FOREIGN KEY (arraydesign_id) REFERENCES chado.arraydesign(arraydesign_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: arraydesignprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.arraydesignprop
    ADD CONSTRAINT arraydesignprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_arraydesign_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_arraydesign_id_fkey FOREIGN KEY (arraydesign_id) REFERENCES chado.arraydesign(arraydesign_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_biomaterial_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial
    ADD CONSTRAINT assay_biomaterial_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_biomaterial_biomaterial_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial
    ADD CONSTRAINT assay_biomaterial_biomaterial_id_fkey FOREIGN KEY (biomaterial_id) REFERENCES chado.biomaterial(biomaterial_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_biomaterial_channel_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_biomaterial
    ADD CONSTRAINT assay_biomaterial_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES chado.channel(channel_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_operator_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_project_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_project
    ADD CONSTRAINT assay_project_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_project_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay_project
    ADD CONSTRAINT assay_project_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assay_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assay
    ADD CONSTRAINT assay_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assayprop_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assayprop
    ADD CONSTRAINT assayprop_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: assayprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.assayprop
    ADD CONSTRAINT assayprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_biosourceprovider_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial
    ADD CONSTRAINT biomaterial_biosourceprovider_id_fkey FOREIGN KEY (biosourceprovider_id) REFERENCES chado.contact(contact_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_dbxref_biomaterial_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_dbxref
    ADD CONSTRAINT biomaterial_dbxref_biomaterial_id_fkey FOREIGN KEY (biomaterial_id) REFERENCES chado.biomaterial(biomaterial_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_dbxref
    ADD CONSTRAINT biomaterial_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial
    ADD CONSTRAINT biomaterial_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship
    ADD CONSTRAINT biomaterial_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.biomaterial(biomaterial_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship
    ADD CONSTRAINT biomaterial_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.biomaterial(biomaterial_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_relationship
    ADD CONSTRAINT biomaterial_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_taxon_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial
    ADD CONSTRAINT biomaterial_taxon_id_fkey FOREIGN KEY (taxon_id) REFERENCES chado.organism(organism_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_treatment_biomaterial_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment
    ADD CONSTRAINT biomaterial_treatment_biomaterial_id_fkey FOREIGN KEY (biomaterial_id) REFERENCES chado.biomaterial(biomaterial_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_treatment_treatment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment
    ADD CONSTRAINT biomaterial_treatment_treatment_id_fkey FOREIGN KEY (treatment_id) REFERENCES chado.treatment(treatment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterial_treatment_unittype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterial_treatment
    ADD CONSTRAINT biomaterial_treatment_unittype_id_fkey FOREIGN KEY (unittype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterialprop_biomaterial_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterialprop
    ADD CONSTRAINT biomaterialprop_biomaterial_id_fkey FOREIGN KEY (biomaterial_id) REFERENCES chado.biomaterial(biomaterial_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: biomaterialprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.biomaterialprop
    ADD CONSTRAINT biomaterialprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_cvterm_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm
    ADD CONSTRAINT cell_line_cvterm_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm
    ADD CONSTRAINT cell_line_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvterm
    ADD CONSTRAINT cell_line_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_cvtermprop_cell_line_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvtermprop
    ADD CONSTRAINT cell_line_cvtermprop_cell_line_cvterm_id_fkey FOREIGN KEY (cell_line_cvterm_id) REFERENCES chado.cell_line_cvterm(cell_line_cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_cvtermprop
    ADD CONSTRAINT cell_line_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_dbxref_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_dbxref
    ADD CONSTRAINT cell_line_dbxref_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_dbxref
    ADD CONSTRAINT cell_line_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_feature_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature
    ADD CONSTRAINT cell_line_feature_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_feature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature
    ADD CONSTRAINT cell_line_feature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_feature_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_feature
    ADD CONSTRAINT cell_line_feature_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_library_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library
    ADD CONSTRAINT cell_line_library_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_library_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library
    ADD CONSTRAINT cell_line_library_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_library_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_library
    ADD CONSTRAINT cell_line_library_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line
    ADD CONSTRAINT cell_line_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_pub_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_pub
    ADD CONSTRAINT cell_line_pub_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_pub
    ADD CONSTRAINT cell_line_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship
    ADD CONSTRAINT cell_line_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship
    ADD CONSTRAINT cell_line_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_relationship
    ADD CONSTRAINT cell_line_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_synonym_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym
    ADD CONSTRAINT cell_line_synonym_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_synonym_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym
    ADD CONSTRAINT cell_line_synonym_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_line_synonym_synonym_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_line_synonym
    ADD CONSTRAINT cell_line_synonym_synonym_id_fkey FOREIGN KEY (synonym_id) REFERENCES chado.synonym(synonym_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_lineprop_cell_line_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop
    ADD CONSTRAINT cell_lineprop_cell_line_id_fkey FOREIGN KEY (cell_line_id) REFERENCES chado.cell_line(cell_line_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_lineprop_pub_cell_lineprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop_pub
    ADD CONSTRAINT cell_lineprop_pub_cell_lineprop_id_fkey FOREIGN KEY (cell_lineprop_id) REFERENCES chado.cell_lineprop(cell_lineprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_lineprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop_pub
    ADD CONSTRAINT cell_lineprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cell_lineprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cell_lineprop
    ADD CONSTRAINT cell_lineprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: chadoprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.chadoprop
    ADD CONSTRAINT chadoprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship
    ADD CONSTRAINT contact_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship
    ADD CONSTRAINT contact_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact_relationship
    ADD CONSTRAINT contact_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: contact_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contact
    ADD CONSTRAINT contact_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: contactprop_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop
    ADD CONSTRAINT contactprop_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE;


--
-- Name: contactprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.contactprop
    ADD CONSTRAINT contactprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: control_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.control
    ADD CONSTRAINT control_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: control_tableinfo_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.control
    ADD CONSTRAINT control_tableinfo_id_fkey FOREIGN KEY (tableinfo_id) REFERENCES chado.tableinfo(tableinfo_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: control_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.control
    ADD CONSTRAINT control_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvprop_cv_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvprop
    ADD CONSTRAINT cvprop_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES chado.cv(cv_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvprop
    ADD CONSTRAINT cvprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_cv_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm
    ADD CONSTRAINT cvterm_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES chado.cv(cv_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_dbxref
    ADD CONSTRAINT cvterm_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm
    ADD CONSTRAINT cvterm_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvterm_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvterm_relationship
    ADD CONSTRAINT cvterm_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_cv_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_cv_id_fkey FOREIGN KEY (cv_id) REFERENCES chado.cv(cv_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermpath_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermpath
    ADD CONSTRAINT cvtermpath_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermprop_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermprop
    ADD CONSTRAINT cvtermprop_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermprop
    ADD CONSTRAINT cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: cvtermsynonym_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: cvtermsynonym_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.cvtermsynonym
    ADD CONSTRAINT cvtermsynonym_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbprop_db_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbprop
    ADD CONSTRAINT dbprop_db_id_fkey FOREIGN KEY (db_id) REFERENCES chado.db(db_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbprop
    ADD CONSTRAINT dbprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxref_db_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxref
    ADD CONSTRAINT dbxref_db_id_fkey FOREIGN KEY (db_id) REFERENCES chado.db(db_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxrefprop_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxrefprop
    ADD CONSTRAINT dbxrefprop_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: dbxrefprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.dbxrefprop
    ADD CONSTRAINT dbxrefprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_arraydesign_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_arraydesign_id_fkey FOREIGN KEY (arraydesign_id) REFERENCES chado.arraydesign(arraydesign_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship
    ADD CONSTRAINT element_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.element(element_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship
    ADD CONSTRAINT element_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.element(element_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element_relationship
    ADD CONSTRAINT element_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: element_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.element
    ADD CONSTRAINT element_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: elementresult_element_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult
    ADD CONSTRAINT elementresult_element_id_fkey FOREIGN KEY (element_id) REFERENCES chado.element(element_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: elementresult_quantification_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult
    ADD CONSTRAINT elementresult_quantification_id_fkey FOREIGN KEY (quantification_id) REFERENCES chado.quantification(quantification_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: elementresult_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship
    ADD CONSTRAINT elementresult_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.elementresult(elementresult_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: elementresult_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship
    ADD CONSTRAINT elementresult_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.elementresult(elementresult_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: elementresult_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.elementresult_relationship
    ADD CONSTRAINT elementresult_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: environment_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment_cvterm
    ADD CONSTRAINT environment_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: environment_cvterm_environment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.environment_cvterm
    ADD CONSTRAINT environment_cvterm_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES chado.environment(environment_id) ON DELETE CASCADE;


--
-- Name: expression_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm
    ADD CONSTRAINT expression_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_cvterm_cvterm_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm
    ADD CONSTRAINT expression_cvterm_cvterm_type_id_fkey FOREIGN KEY (cvterm_type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_cvterm_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvterm
    ADD CONSTRAINT expression_cvterm_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_cvtermprop_expression_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvtermprop
    ADD CONSTRAINT expression_cvtermprop_expression_cvterm_id_fkey FOREIGN KEY (expression_cvterm_id) REFERENCES chado.expression_cvterm(expression_cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_cvtermprop
    ADD CONSTRAINT expression_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_image_eimage_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_image
    ADD CONSTRAINT expression_image_eimage_id_fkey FOREIGN KEY (eimage_id) REFERENCES chado.eimage(eimage_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_image_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_image
    ADD CONSTRAINT expression_image_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_pub_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_pub
    ADD CONSTRAINT expression_pub_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expression_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expression_pub
    ADD CONSTRAINT expression_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expressionprop_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expressionprop
    ADD CONSTRAINT expressionprop_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: expressionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.expressionprop
    ADD CONSTRAINT expressionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_contact
    ADD CONSTRAINT feature_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE;


--
-- Name: feature_contact_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_contact
    ADD CONSTRAINT feature_contact_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm
    ADD CONSTRAINT feature_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_dbxref_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_dbxref
    ADD CONSTRAINT feature_cvterm_dbxref_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES chado.feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm
    ADD CONSTRAINT feature_cvterm_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_pub_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES chado.feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm
    ADD CONSTRAINT feature_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvterm_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvterm_pub
    ADD CONSTRAINT feature_cvterm_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_cvtermprop_feature_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_feature_cvterm_id_fkey FOREIGN KEY (feature_cvterm_id) REFERENCES chado.feature_cvterm(feature_cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_cvtermprop
    ADD CONSTRAINT feature_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_dbxref
    ADD CONSTRAINT feature_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_dbxref
    ADD CONSTRAINT feature_dbxref_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature
    ADD CONSTRAINT feature_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_expression_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression
    ADD CONSTRAINT feature_expression_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_expression_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression
    ADD CONSTRAINT feature_expression_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_expression_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expression
    ADD CONSTRAINT feature_expression_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_expressionprop_feature_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expressionprop
    ADD CONSTRAINT feature_expressionprop_feature_expression_id_fkey FOREIGN KEY (feature_expression_id) REFERENCES chado.feature_expression(feature_expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_expressionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_expressionprop
    ADD CONSTRAINT feature_expressionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_genotype_chromosome_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_chromosome_id_fkey FOREIGN KEY (chromosome_id) REFERENCES chado.feature(feature_id) ON DELETE SET NULL;


--
-- Name: feature_genotype_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: feature_genotype_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: feature_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_genotype
    ADD CONSTRAINT feature_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: feature_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature
    ADD CONSTRAINT feature_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_phenotype_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_phenotype
    ADD CONSTRAINT feature_phenotype_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: feature_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_phenotype
    ADD CONSTRAINT feature_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: feature_project_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_project
    ADD CONSTRAINT feature_project_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_project_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_project
    ADD CONSTRAINT feature_project_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pub_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pub
    ADD CONSTRAINT feature_pub_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pub
    ADD CONSTRAINT feature_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pubprop_feature_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pubprop
    ADD CONSTRAINT feature_pubprop_feature_pub_id_fkey FOREIGN KEY (feature_pub_id) REFERENCES chado.feature_pub(feature_pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_pubprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_pubprop
    ADD CONSTRAINT feature_pubprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship
    ADD CONSTRAINT feature_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_pub_feature_relationship_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_feature_relationship_id_fkey FOREIGN KEY (feature_relationship_id) REFERENCES chado.feature_relationship(feature_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship_pub
    ADD CONSTRAINT feature_relationship_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship
    ADD CONSTRAINT feature_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationship
    ADD CONSTRAINT feature_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_feature_relationship_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_feature_relationship_id_fkey FOREIGN KEY (feature_relationship_id) REFERENCES chado.feature_relationship(feature_relationship_id) ON DELETE CASCADE;


--
-- Name: feature_relationshipprop_pub_feature_relationshipprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_feature_relationshipprop_id_fkey FOREIGN KEY (feature_relationshipprop_id) REFERENCES chado.feature_relationshipprop(feature_relationshipprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop_pub
    ADD CONSTRAINT feature_relationshipprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_relationshipprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_relationshipprop
    ADD CONSTRAINT feature_relationshipprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_stock_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock
    ADD CONSTRAINT feature_stock_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock
    ADD CONSTRAINT feature_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_stock_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_stock
    ADD CONSTRAINT feature_stock_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym
    ADD CONSTRAINT feature_synonym_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym
    ADD CONSTRAINT feature_synonym_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_synonym_synonym_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature_synonym
    ADD CONSTRAINT feature_synonym_synonym_id_fkey FOREIGN KEY (synonym_id) REFERENCES chado.synonym(synonym_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: feature_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.feature
    ADD CONSTRAINT feature_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc
    ADD CONSTRAINT featureloc_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_pub_featureloc_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc_pub
    ADD CONSTRAINT featureloc_pub_featureloc_id_fkey FOREIGN KEY (featureloc_id) REFERENCES chado.featureloc(featureloc_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc_pub
    ADD CONSTRAINT featureloc_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureloc_srcfeature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureloc
    ADD CONSTRAINT featureloc_srcfeature_id_fkey FOREIGN KEY (srcfeature_id) REFERENCES chado.feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurelocprop_featureloc_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurelocprop
    ADD CONSTRAINT featurelocprop_featureloc_id_fkey FOREIGN KEY (featureloc_id) REFERENCES chado.featureloc(featureloc_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurelocprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurelocprop
    ADD CONSTRAINT featurelocprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_contact
    ADD CONSTRAINT featuremap_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE;


--
-- Name: featuremap_contact_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_contact
    ADD CONSTRAINT featuremap_contact_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE;


--
-- Name: featuremap_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_dbxref
    ADD CONSTRAINT featuremap_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_dbxref_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_dbxref
    ADD CONSTRAINT featuremap_dbxref_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_organism_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_organism
    ADD CONSTRAINT featuremap_organism_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE;


--
-- Name: featuremap_organism_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_organism
    ADD CONSTRAINT featuremap_organism_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE;


--
-- Name: featuremap_pub_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_pub
    ADD CONSTRAINT featuremap_pub_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_pub
    ADD CONSTRAINT featuremap_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_stock_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_stock
    ADD CONSTRAINT featuremap_stock_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap_stock
    ADD CONSTRAINT featuremap_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremap_unittype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremap
    ADD CONSTRAINT featuremap_unittype_id_fkey FOREIGN KEY (unittype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featuremapprop_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop
    ADD CONSTRAINT featuremapprop_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE;


--
-- Name: featuremapprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featuremapprop
    ADD CONSTRAINT featuremapprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: featurepos_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurepos
    ADD CONSTRAINT featurepos_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurepos_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurepos
    ADD CONSTRAINT featurepos_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurepos_map_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurepos
    ADD CONSTRAINT featurepos_map_feature_id_fkey FOREIGN KEY (map_feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureposprop_featurepos_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop
    ADD CONSTRAINT featureposprop_featurepos_id_fkey FOREIGN KEY (featurepos_id) REFERENCES chado.featurepos(featurepos_id) ON DELETE CASCADE;


--
-- Name: featureposprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureposprop
    ADD CONSTRAINT featureposprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: featureprop_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop
    ADD CONSTRAINT featureprop_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_pub_featureprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop_pub
    ADD CONSTRAINT featureprop_pub_featureprop_id_fkey FOREIGN KEY (featureprop_id) REFERENCES chado.featureprop(featureprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop_pub
    ADD CONSTRAINT featureprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featureprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featureprop
    ADD CONSTRAINT featureprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_leftendf_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_leftendf_id_fkey FOREIGN KEY (leftendf_id) REFERENCES chado.feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_leftstartf_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_leftstartf_id_fkey FOREIGN KEY (leftstartf_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_rightendf_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_rightendf_id_fkey FOREIGN KEY (rightendf_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: featurerange_rightstartf_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.featurerange
    ADD CONSTRAINT featurerange_rightstartf_id_fkey FOREIGN KEY (rightstartf_id) REFERENCES chado.feature(feature_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genome_metadata_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genome_metadata
    ADD CONSTRAINT genome_metadata_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genome_metadata_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genome_metadata
    ADD CONSTRAINT genome_metadata_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genome_metadata_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genome_metadata
    ADD CONSTRAINT genome_metadata_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genome_metadata_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genome_metadata
    ADD CONSTRAINT genome_metadata_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genotype_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotype
    ADD CONSTRAINT genotype_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: genotypeprop_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotypeprop
    ADD CONSTRAINT genotypeprop_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: genotypeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.genotypeprop
    ADD CONSTRAINT genotypeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_contact
    ADD CONSTRAINT library_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE;


--
-- Name: library_contact_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_contact
    ADD CONSTRAINT library_contact_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE;


--
-- Name: library_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm
    ADD CONSTRAINT library_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: library_cvterm_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm
    ADD CONSTRAINT library_cvterm_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_cvterm
    ADD CONSTRAINT library_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id);


--
-- Name: library_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_dbxref
    ADD CONSTRAINT library_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_dbxref_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_dbxref
    ADD CONSTRAINT library_dbxref_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_expression_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression
    ADD CONSTRAINT library_expression_expression_id_fkey FOREIGN KEY (expression_id) REFERENCES chado.expression(expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_expression_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression
    ADD CONSTRAINT library_expression_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_expression_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expression
    ADD CONSTRAINT library_expression_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id);


--
-- Name: library_expressionprop_library_expression_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expressionprop
    ADD CONSTRAINT library_expressionprop_library_expression_id_fkey FOREIGN KEY (library_expression_id) REFERENCES chado.library_expression(library_expression_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_expressionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_expressionprop
    ADD CONSTRAINT library_expressionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: library_feature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_feature
    ADD CONSTRAINT library_feature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_feature_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_feature
    ADD CONSTRAINT library_feature_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_featureprop_library_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_featureprop
    ADD CONSTRAINT library_featureprop_library_feature_id_fkey FOREIGN KEY (library_feature_id) REFERENCES chado.library_feature(library_feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_featureprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_featureprop
    ADD CONSTRAINT library_featureprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: library_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library
    ADD CONSTRAINT library_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id);


--
-- Name: library_pub_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_pub
    ADD CONSTRAINT library_pub_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_pub
    ADD CONSTRAINT library_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship
    ADD CONSTRAINT library_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_relationship_pub_library_relationship_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship_pub
    ADD CONSTRAINT library_relationship_pub_library_relationship_id_fkey FOREIGN KEY (library_relationship_id) REFERENCES chado.library_relationship(library_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_relationship_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship_pub
    ADD CONSTRAINT library_relationship_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id);


--
-- Name: library_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship
    ADD CONSTRAINT library_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_relationship
    ADD CONSTRAINT library_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: library_synonym_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym
    ADD CONSTRAINT library_synonym_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_synonym_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym
    ADD CONSTRAINT library_synonym_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_synonym_synonym_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library_synonym
    ADD CONSTRAINT library_synonym_synonym_id_fkey FOREIGN KEY (synonym_id) REFERENCES chado.synonym(synonym_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: library_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.library
    ADD CONSTRAINT library_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: libraryprop_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop
    ADD CONSTRAINT libraryprop_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: libraryprop_pub_libraryprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop_pub
    ADD CONSTRAINT libraryprop_pub_libraryprop_id_fkey FOREIGN KEY (libraryprop_id) REFERENCES chado.libraryprop(libraryprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: libraryprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop_pub
    ADD CONSTRAINT libraryprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: libraryprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.libraryprop
    ADD CONSTRAINT libraryprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: magedocumentation_mageml_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.magedocumentation
    ADD CONSTRAINT magedocumentation_mageml_id_fkey FOREIGN KEY (mageml_id) REFERENCES chado.mageml(mageml_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: magedocumentation_tableinfo_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.magedocumentation
    ADD CONSTRAINT magedocumentation_tableinfo_id_fkey FOREIGN KEY (tableinfo_id) REFERENCES chado.tableinfo(tableinfo_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_analysis_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_analysis
    ADD CONSTRAINT nd_experiment_analysis_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_analysis_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_analysis
    ADD CONSTRAINT nd_experiment_analysis_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_analysis_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_analysis
    ADD CONSTRAINT nd_experiment_analysis_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_contact_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_contact
    ADD CONSTRAINT nd_experiment_contact_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_dbxref_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_dbxref
    ADD CONSTRAINT nd_experiment_dbxref_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_genotype_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_genotype
    ADD CONSTRAINT nd_experiment_genotype_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_nd_geolocation_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment
    ADD CONSTRAINT nd_experiment_nd_geolocation_id_fkey FOREIGN KEY (nd_geolocation_id) REFERENCES chado.nd_geolocation(nd_geolocation_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_phenotype_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_phenotype
    ADD CONSTRAINT nd_experiment_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_project_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_project_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_project
    ADD CONSTRAINT nd_experiment_project_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_protocol_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_protocol_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_protocol
    ADD CONSTRAINT nd_experiment_protocol_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES chado.nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_pub_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_pub
    ADD CONSTRAINT nd_experiment_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_dbxref_nd_experiment_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock_dbxref
    ADD CONSTRAINT nd_experiment_stock_dbxref_nd_experiment_stock_id_fkey FOREIGN KEY (nd_experiment_stock_id) REFERENCES chado.nd_experiment_stock(nd_experiment_stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stock_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stock
    ADD CONSTRAINT nd_experiment_stock_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stockprop_nd_experiment_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_nd_experiment_stock_id_fkey FOREIGN KEY (nd_experiment_stock_id) REFERENCES chado.nd_experiment_stock(nd_experiment_stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_stockprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment_stockprop
    ADD CONSTRAINT nd_experiment_stockprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experiment_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experiment
    ADD CONSTRAINT nd_experiment_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experimentprop_nd_experiment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_nd_experiment_id_fkey FOREIGN KEY (nd_experiment_id) REFERENCES chado.nd_experiment(nd_experiment_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_experimentprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_experimentprop
    ADD CONSTRAINT nd_experimentprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_geolocationprop_nd_geolocation_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_nd_geolocation_id_fkey FOREIGN KEY (nd_geolocation_id) REFERENCES chado.nd_geolocation(nd_geolocation_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_geolocationprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_geolocationprop
    ADD CONSTRAINT nd_geolocationprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES chado.nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_reagent_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_reagent_id_fkey FOREIGN KEY (reagent_id) REFERENCES chado.nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_reagent_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol_reagent
    ADD CONSTRAINT nd_protocol_reagent_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocol_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocol
    ADD CONSTRAINT nd_protocol_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocolprop_nd_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_nd_protocol_id_fkey FOREIGN KEY (nd_protocol_id) REFERENCES chado.nd_protocol(nd_protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_protocolprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_protocolprop
    ADD CONSTRAINT nd_protocolprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent
    ADD CONSTRAINT nd_reagent_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_object_reagent_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_object_reagent_id_fkey FOREIGN KEY (object_reagent_id) REFERENCES chado.nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_subject_reagent_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_subject_reagent_id_fkey FOREIGN KEY (subject_reagent_id) REFERENCES chado.nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent_relationship
    ADD CONSTRAINT nd_reagent_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagent_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagent
    ADD CONSTRAINT nd_reagent_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagentprop_nd_reagent_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_nd_reagent_id_fkey FOREIGN KEY (nd_reagent_id) REFERENCES chado.nd_reagent(nd_reagent_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: nd_reagentprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.nd_reagentprop
    ADD CONSTRAINT nd_reagentprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm
    ADD CONSTRAINT organism_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_cvterm_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm
    ADD CONSTRAINT organism_cvterm_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvterm
    ADD CONSTRAINT organism_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_cvtermprop_organism_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvtermprop
    ADD CONSTRAINT organism_cvtermprop_organism_cvterm_id_fkey FOREIGN KEY (organism_cvterm_id) REFERENCES chado.organism_cvterm(organism_cvterm_id) ON DELETE CASCADE;


--
-- Name: organism_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_cvtermprop
    ADD CONSTRAINT organism_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_dbxref
    ADD CONSTRAINT organism_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_dbxref_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_dbxref
    ADD CONSTRAINT organism_dbxref_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_pub_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_pub
    ADD CONSTRAINT organism_pub_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_pub
    ADD CONSTRAINT organism_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organism_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship
    ADD CONSTRAINT organism_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE;


--
-- Name: organism_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship
    ADD CONSTRAINT organism_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE;


--
-- Name: organism_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism_relationship
    ADD CONSTRAINT organism_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: organism_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organism
    ADD CONSTRAINT organism_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: organismprop_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop
    ADD CONSTRAINT organismprop_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organismprop_pub_organismprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop_pub
    ADD CONSTRAINT organismprop_pub_organismprop_id_fkey FOREIGN KEY (organismprop_id) REFERENCES chado.organismprop(organismprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organismprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop_pub
    ADD CONSTRAINT organismprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: organismprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.organismprop
    ADD CONSTRAINT organismprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phendesc_environment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES chado.environment(environment_id) ON DELETE CASCADE;


--
-- Name: phendesc_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phendesc_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phendesc_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phendesc
    ADD CONSTRAINT phendesc_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_attr_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_attr_id_fkey FOREIGN KEY (attr_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_comparison_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_cvterm_phenotype_comparison_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_phenotype_comparison_id_fkey FOREIGN KEY (phenotype_comparison_id) REFERENCES chado.phenotype_comparison(phenotype_comparison_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison_cvterm
    ADD CONSTRAINT phenotype_comparison_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_environment1_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_environment1_id_fkey FOREIGN KEY (environment1_id) REFERENCES chado.environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_environment2_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_environment2_id_fkey FOREIGN KEY (environment2_id) REFERENCES chado.environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_genotype1_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_genotype1_id_fkey FOREIGN KEY (genotype1_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_genotype2_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_genotype2_id_fkey FOREIGN KEY (genotype2_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_phenotype1_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_phenotype1_id_fkey FOREIGN KEY (phenotype1_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_phenotype2_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_phenotype2_id_fkey FOREIGN KEY (phenotype2_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_comparison_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_comparison
    ADD CONSTRAINT phenotype_comparison_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenotype_cvalue_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_cvalue_id_fkey FOREIGN KEY (cvalue_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL;


--
-- Name: phenotype_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotype_cvterm_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype_cvterm
    ADD CONSTRAINT phenotype_cvterm_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenotype_observable_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotype
    ADD CONSTRAINT phenotype_observable_id_fkey FOREIGN KEY (observable_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phenotypeprop_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotypeprop
    ADD CONSTRAINT phenotypeprop_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phenotypeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenotypeprop
    ADD CONSTRAINT phenotypeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phenstatement_environment_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_environment_id_fkey FOREIGN KEY (environment_id) REFERENCES chado.environment(environment_id) ON DELETE CASCADE;


--
-- Name: phenstatement_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: phenstatement_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE;


--
-- Name: phenstatement_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phenstatement_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phenstatement
    ADD CONSTRAINT phenstatement_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phylonode_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_dbxref
    ADD CONSTRAINT phylonode_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE;


--
-- Name: phylonode_dbxref_phylonode_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_dbxref
    ADD CONSTRAINT phylonode_dbxref_phylonode_id_fkey FOREIGN KEY (phylonode_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: phylonode_organism_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_organism
    ADD CONSTRAINT phylonode_organism_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE;


--
-- Name: phylonode_organism_phylonode_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_organism
    ADD CONSTRAINT phylonode_organism_phylonode_id_fkey FOREIGN KEY (phylonode_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_parent_phylonode_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_parent_phylonode_id_fkey FOREIGN KEY (parent_phylonode_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_phylotree_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_phylotree_id_fkey FOREIGN KEY (phylotree_id) REFERENCES chado.phylotree(phylotree_id) ON DELETE CASCADE;


--
-- Name: phylonode_pub_phylonode_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_pub
    ADD CONSTRAINT phylonode_pub_phylonode_id_fkey FOREIGN KEY (phylonode_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_pub
    ADD CONSTRAINT phylonode_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phylonode_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_relationship_phylotree_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_phylotree_id_fkey FOREIGN KEY (phylotree_id) REFERENCES chado.phylotree(phylotree_id) ON DELETE CASCADE;


--
-- Name: phylonode_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonode_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode_relationship
    ADD CONSTRAINT phylonode_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phylonode_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonode
    ADD CONSTRAINT phylonode_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phylonodeprop_phylonode_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonodeprop
    ADD CONSTRAINT phylonodeprop_phylonode_id_fkey FOREIGN KEY (phylonode_id) REFERENCES chado.phylonode(phylonode_id) ON DELETE CASCADE;


--
-- Name: phylonodeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylonodeprop
    ADD CONSTRAINT phylonodeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phylotree_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree
    ADD CONSTRAINT phylotree_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE;


--
-- Name: phylotree_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree
    ADD CONSTRAINT phylotree_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE;


--
-- Name: phylotree_pub_phylotree_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree_pub
    ADD CONSTRAINT phylotree_pub_phylotree_id_fkey FOREIGN KEY (phylotree_id) REFERENCES chado.phylotree(phylotree_id) ON DELETE CASCADE;


--
-- Name: phylotree_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree_pub
    ADD CONSTRAINT phylotree_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE;


--
-- Name: phylotree_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotree
    ADD CONSTRAINT phylotree_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: phylotreeprop_phylotree_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotreeprop
    ADD CONSTRAINT phylotreeprop_phylotree_id_fkey FOREIGN KEY (phylotree_id) REFERENCES chado.phylotree(phylotree_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: phylotreeprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.phylotreeprop
    ADD CONSTRAINT phylotreeprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_analysis_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_analysis
    ADD CONSTRAINT project_analysis_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_analysis_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_analysis
    ADD CONSTRAINT project_analysis_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_contact
    ADD CONSTRAINT project_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_contact_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_contact
    ADD CONSTRAINT project_contact_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_dbxref
    ADD CONSTRAINT project_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_dbxref_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_dbxref
    ADD CONSTRAINT project_dbxref_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_feature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_feature
    ADD CONSTRAINT project_feature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: project_feature_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_feature
    ADD CONSTRAINT project_feature_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE;


--
-- Name: project_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_phenotype
    ADD CONSTRAINT project_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_phenotype_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_phenotype
    ADD CONSTRAINT project_phenotype_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_pub_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_pub
    ADD CONSTRAINT project_pub_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_pub
    ADD CONSTRAINT project_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: project_relationship_object_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship
    ADD CONSTRAINT project_relationship_object_project_id_fkey FOREIGN KEY (object_project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE;


--
-- Name: project_relationship_subject_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship
    ADD CONSTRAINT project_relationship_subject_project_id_fkey FOREIGN KEY (subject_project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE;


--
-- Name: project_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_relationship
    ADD CONSTRAINT project_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE RESTRICT;


--
-- Name: project_stock_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_stock
    ADD CONSTRAINT project_stock_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE;


--
-- Name: project_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.project_stock
    ADD CONSTRAINT project_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE;


--
-- Name: projectprop_project_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.projectprop
    ADD CONSTRAINT projectprop_project_id_fkey FOREIGN KEY (project_id) REFERENCES chado.project(project_id) ON DELETE CASCADE;


--
-- Name: projectprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.projectprop
    ADD CONSTRAINT projectprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: protocol_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol
    ADD CONSTRAINT protocol_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: protocol_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol
    ADD CONSTRAINT protocol_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: protocol_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocol
    ADD CONSTRAINT protocol_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: protocolparam_datatype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocolparam
    ADD CONSTRAINT protocolparam_datatype_id_fkey FOREIGN KEY (datatype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: protocolparam_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocolparam
    ADD CONSTRAINT protocolparam_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: protocolparam_unittype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.protocolparam
    ADD CONSTRAINT protocolparam_unittype_id_fkey FOREIGN KEY (unittype_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_dbxref
    ADD CONSTRAINT pub_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_dbxref_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_dbxref
    ADD CONSTRAINT pub_dbxref_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship
    ADD CONSTRAINT pub_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship
    ADD CONSTRAINT pub_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub_relationship
    ADD CONSTRAINT pub_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pub_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pub
    ADD CONSTRAINT pub_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubauthor_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor_contact
    ADD CONSTRAINT pubauthor_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE;


--
-- Name: pubauthor_contact_pubauthor_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor_contact
    ADD CONSTRAINT pubauthor_contact_pubauthor_id_fkey FOREIGN KEY (pubauthor_id) REFERENCES chado.pubauthor(pubauthor_id) ON DELETE CASCADE;


--
-- Name: pubauthor_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubauthor
    ADD CONSTRAINT pubauthor_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubprop_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubprop
    ADD CONSTRAINT pubprop_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: pubprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.pubprop
    ADD CONSTRAINT pubprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_acquisition_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_acquisition_id_fkey FOREIGN KEY (acquisition_id) REFERENCES chado.acquisition(acquisition_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_analysis_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_analysis_id_fkey FOREIGN KEY (analysis_id) REFERENCES chado.analysis(analysis_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_operator_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES chado.contact(contact_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification
    ADD CONSTRAINT quantification_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship
    ADD CONSTRAINT quantification_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.quantification(quantification_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship
    ADD CONSTRAINT quantification_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.quantification(quantification_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantification_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantification_relationship
    ADD CONSTRAINT quantification_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantificationprop_quantification_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantificationprop
    ADD CONSTRAINT quantificationprop_quantification_id_fkey FOREIGN KEY (quantification_id) REFERENCES chado.quantification(quantification_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: quantificationprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.quantificationprop
    ADD CONSTRAINT quantificationprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm
    ADD CONSTRAINT stock_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm
    ADD CONSTRAINT stock_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvterm_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvterm
    ADD CONSTRAINT stock_cvterm_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_cvtermprop_stock_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_stock_cvterm_id_fkey FOREIGN KEY (stock_cvterm_id) REFERENCES chado.stock_cvterm(stock_cvterm_id) ON DELETE CASCADE;


--
-- Name: stock_cvtermprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_cvtermprop
    ADD CONSTRAINT stock_cvtermprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxref
    ADD CONSTRAINT stock_dbxref_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock
    ADD CONSTRAINT stock_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxref_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxref
    ADD CONSTRAINT stock_dbxref_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxrefprop_stock_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_stock_dbxref_id_fkey FOREIGN KEY (stock_dbxref_id) REFERENCES chado.stock_dbxref(stock_dbxref_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_dbxrefprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_dbxrefprop
    ADD CONSTRAINT stock_dbxrefprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_eimage_eimage_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_eimage
    ADD CONSTRAINT stock_eimage_eimage_id_fkey FOREIGN KEY (eimage_id) REFERENCES chado.eimage(eimage_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_eimage_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_eimage
    ADD CONSTRAINT stock_eimage_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_feature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature
    ADD CONSTRAINT stock_feature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_feature_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature
    ADD CONSTRAINT stock_feature_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_feature_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_feature
    ADD CONSTRAINT stock_feature_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_featuremap_featuremap_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_featuremap
    ADD CONSTRAINT stock_featuremap_featuremap_id_fkey FOREIGN KEY (featuremap_id) REFERENCES chado.featuremap(featuremap_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_featuremap_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_featuremap
    ADD CONSTRAINT stock_featuremap_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_featuremap_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_featuremap
    ADD CONSTRAINT stock_featuremap_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_genotype_genotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_genotype
    ADD CONSTRAINT stock_genotype_genotype_id_fkey FOREIGN KEY (genotype_id) REFERENCES chado.genotype(genotype_id) ON DELETE CASCADE;


--
-- Name: stock_genotype_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_genotype
    ADD CONSTRAINT stock_genotype_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE;


--
-- Name: stock_library_library_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_library
    ADD CONSTRAINT stock_library_library_id_fkey FOREIGN KEY (library_id) REFERENCES chado.library(library_id) ON DELETE CASCADE;


--
-- Name: stock_library_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_library
    ADD CONSTRAINT stock_library_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE;


--
-- Name: stock_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock
    ADD CONSTRAINT stock_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_organism_organism_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_organism
    ADD CONSTRAINT stock_organism_organism_id_fkey FOREIGN KEY (organism_id) REFERENCES chado.organism(organism_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_organism_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_organism
    ADD CONSTRAINT stock_organism_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_phenotype_phenotype_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_phenotype
    ADD CONSTRAINT stock_phenotype_phenotype_id_fkey FOREIGN KEY (phenotype_id) REFERENCES chado.phenotype(phenotype_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_phenotype_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_phenotype
    ADD CONSTRAINT stock_phenotype_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_pub
    ADD CONSTRAINT stock_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_pub_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_pub
    ADD CONSTRAINT stock_pub_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_cvterm_cvterm_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_cvterm_id_fkey FOREIGN KEY (cvterm_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE RESTRICT;


--
-- Name: stock_relationship_cvterm_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE RESTRICT;


--
-- Name: stock_relationship_cvterm_stock_relationship_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_cvterm
    ADD CONSTRAINT stock_relationship_cvterm_stock_relationship_id_fkey FOREIGN KEY (stock_relationship_id) REFERENCES chado.stock_relationship(stock_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_object_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship
    ADD CONSTRAINT stock_relationship_object_id_fkey FOREIGN KEY (object_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_pub_stock_relationship_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship_pub
    ADD CONSTRAINT stock_relationship_pub_stock_relationship_id_fkey FOREIGN KEY (stock_relationship_id) REFERENCES chado.stock_relationship(stock_relationship_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_subject_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship
    ADD CONSTRAINT stock_relationship_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_relationship_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock_relationship
    ADD CONSTRAINT stock_relationship_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stock_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stock
    ADD CONSTRAINT stock_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection
    ADD CONSTRAINT stockcollection_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_db_db_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_db
    ADD CONSTRAINT stockcollection_db_db_id_fkey FOREIGN KEY (db_id) REFERENCES chado.db(db_id) ON DELETE CASCADE;


--
-- Name: stockcollection_db_stockcollection_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_db
    ADD CONSTRAINT stockcollection_db_stockcollection_id_fkey FOREIGN KEY (stockcollection_id) REFERENCES chado.stockcollection(stockcollection_id) ON DELETE CASCADE;


--
-- Name: stockcollection_stock_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_stock_stockcollection_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection_stock
    ADD CONSTRAINT stockcollection_stock_stockcollection_id_fkey FOREIGN KEY (stockcollection_id) REFERENCES chado.stockcollection(stockcollection_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollection_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollection
    ADD CONSTRAINT stockcollection_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: stockcollectionprop_stockcollection_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_stockcollection_id_fkey FOREIGN KEY (stockcollection_id) REFERENCES chado.stockcollection(stockcollection_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockcollectionprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockcollectionprop
    ADD CONSTRAINT stockcollectionprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id);


--
-- Name: stockprop_pub_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop_pub
    ADD CONSTRAINT stockprop_pub_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_pub_stockprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop_pub
    ADD CONSTRAINT stockprop_pub_stockprop_id_fkey FOREIGN KEY (stockprop_id) REFERENCES chado.stockprop(stockprop_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_stock_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop
    ADD CONSTRAINT stockprop_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES chado.stock(stock_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: stockprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.stockprop
    ADD CONSTRAINT stockprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: study_assay_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study_assay
    ADD CONSTRAINT study_assay_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: study_assay_study_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study_assay
    ADD CONSTRAINT study_assay_study_id_fkey FOREIGN KEY (study_id) REFERENCES chado.study(study_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: study_contact_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study
    ADD CONSTRAINT study_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES chado.contact(contact_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: study_dbxref_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study
    ADD CONSTRAINT study_dbxref_id_fkey FOREIGN KEY (dbxref_id) REFERENCES chado.dbxref(dbxref_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: study_pub_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.study
    ADD CONSTRAINT study_pub_id_fkey FOREIGN KEY (pub_id) REFERENCES chado.pub(pub_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studydesign_study_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesign
    ADD CONSTRAINT studydesign_study_id_fkey FOREIGN KEY (study_id) REFERENCES chado.study(study_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studydesignprop_studydesign_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesignprop
    ADD CONSTRAINT studydesignprop_studydesign_id_fkey FOREIGN KEY (studydesign_id) REFERENCES chado.studydesign(studydesign_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studydesignprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studydesignprop
    ADD CONSTRAINT studydesignprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studyfactor_studydesign_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactor
    ADD CONSTRAINT studyfactor_studydesign_id_fkey FOREIGN KEY (studydesign_id) REFERENCES chado.studydesign(studydesign_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studyfactor_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactor
    ADD CONSTRAINT studyfactor_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studyfactorvalue_assay_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactorvalue
    ADD CONSTRAINT studyfactorvalue_assay_id_fkey FOREIGN KEY (assay_id) REFERENCES chado.assay(assay_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studyfactorvalue_studyfactor_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyfactorvalue
    ADD CONSTRAINT studyfactorvalue_studyfactor_id_fkey FOREIGN KEY (studyfactor_id) REFERENCES chado.studyfactor(studyfactor_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: studyprop_feature_feature_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature
    ADD CONSTRAINT studyprop_feature_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES chado.feature(feature_id) ON DELETE CASCADE;


--
-- Name: studyprop_feature_studyprop_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature
    ADD CONSTRAINT studyprop_feature_studyprop_id_fkey FOREIGN KEY (studyprop_id) REFERENCES chado.studyprop(studyprop_id) ON DELETE CASCADE;


--
-- Name: studyprop_feature_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop_feature
    ADD CONSTRAINT studyprop_feature_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: studyprop_study_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop
    ADD CONSTRAINT studyprop_study_id_fkey FOREIGN KEY (study_id) REFERENCES chado.study(study_id) ON DELETE CASCADE;


--
-- Name: studyprop_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.studyprop
    ADD CONSTRAINT studyprop_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE;


--
-- Name: synonym_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.synonym
    ADD CONSTRAINT synonym_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: tmp_cds_handler_relationship_cds_row_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.tmp_cds_handler_relationship
    ADD CONSTRAINT tmp_cds_handler_relationship_cds_row_id_fkey FOREIGN KEY (cds_row_id) REFERENCES chado.tmp_cds_handler(cds_row_id) ON DELETE CASCADE;


--
-- Name: treatment_biomaterial_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.treatment
    ADD CONSTRAINT treatment_biomaterial_id_fkey FOREIGN KEY (biomaterial_id) REFERENCES chado.biomaterial(biomaterial_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: treatment_protocol_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.treatment
    ADD CONSTRAINT treatment_protocol_id_fkey FOREIGN KEY (protocol_id) REFERENCES chado.protocol(protocol_id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED;


--
-- Name: treatment_type_id_fkey; Type: FK CONSTRAINT; Schema: chado; Owner: www
--

ALTER TABLE ONLY chado.treatment
    ADD CONSTRAINT treatment_type_id_fkey FOREIGN KEY (type_id) REFERENCES chado.cvterm(cvterm_id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;


--
-- Name: SCHEMA chado; Type: ACL; Schema: -; Owner: www
--

REVOKE ALL ON SCHEMA chado FROM PUBLIC;
REVOKE ALL ON SCHEMA chado FROM www;
GRANT ALL ON SCHEMA chado TO www;
GRANT ALL ON SCHEMA chado TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node(bigint, bigint, bigint, bigint, integer) TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4node2detect_cycle(bigint, bigint, bigint, bigint, integer) TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4root(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4root(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4root(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root(bigint, bigint) TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4root2detect_cycle(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4root2detect_cycle(bigint, bigint) TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4soi(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4soi(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4soi(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soi(integer, integer) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soi(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soi(integer, integer) TO staff;


--
-- Name: FUNCTION _fill_cvtermpath4soinode(integer, integer, integer, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) TO www;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._fill_cvtermpath4soinode(integer, integer, integer, integer, integer) TO staff;


--
-- Name: TABLE cvtermpath; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvtermpath FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvtermpath FROM www;
GRANT ALL ON TABLE chado.cvtermpath TO www;
GRANT ALL ON TABLE chado.cvtermpath TO staff;


--
-- Name: FUNCTION _get_all_object_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._get_all_object_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._get_all_object_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado._get_all_object_ids(integer) TO www;
GRANT ALL ON FUNCTION chado._get_all_object_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._get_all_object_ids(integer) TO staff;


--
-- Name: FUNCTION _get_all_subject_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado._get_all_subject_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado._get_all_subject_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado._get_all_subject_ids(integer) TO www;
GRANT ALL ON FUNCTION chado._get_all_subject_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado._get_all_subject_ids(integer) TO staff;


--
-- Name: FUNCTION boxquery(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.boxquery(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.boxquery(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint) TO staff;


--
-- Name: FUNCTION boxquery(bigint, bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.boxquery(bigint, bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.boxquery(bigint, bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.boxquery(bigint, bigint, bigint) TO staff;


--
-- Name: FUNCTION boxrange(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.boxrange(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.boxrange(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint) TO staff;


--
-- Name: FUNCTION boxrange(bigint, bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.boxrange(bigint, bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.boxrange(bigint, bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.boxrange(bigint, bigint, bigint) TO staff;


--
-- Name: FUNCTION complement_residues(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.complement_residues(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.complement_residues(text) FROM www;
GRANT ALL ON FUNCTION chado.complement_residues(text) TO www;
GRANT ALL ON FUNCTION chado.complement_residues(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.complement_residues(text) TO staff;


--
-- Name: FUNCTION concat_pair(text, text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.concat_pair(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.concat_pair(text, text) FROM www;
GRANT ALL ON FUNCTION chado.concat_pair(text, text) TO www;
GRANT ALL ON FUNCTION chado.concat_pair(text, text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.concat_pair(text, text) TO staff;


--
-- Name: FUNCTION create_point(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.create_point(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.create_point(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.create_point(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.create_point(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.create_point(bigint, bigint) TO staff;


--
-- Name: FUNCTION create_soi(); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.create_soi() FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.create_soi() FROM www;
GRANT ALL ON FUNCTION chado.create_soi() TO www;
GRANT ALL ON FUNCTION chado.create_soi() TO PUBLIC;
GRANT ALL ON FUNCTION chado.create_soi() TO staff;


--
-- Name: TABLE feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature FROM www;
GRANT ALL ON TABLE chado.feature TO www;
GRANT ALL ON TABLE chado.feature TO staff;


--
-- Name: FUNCTION feature_disjoint_from(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.feature_disjoint_from(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.feature_disjoint_from(bigint) FROM www;
GRANT ALL ON FUNCTION chado.feature_disjoint_from(bigint) TO www;
GRANT ALL ON FUNCTION chado.feature_disjoint_from(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.feature_disjoint_from(bigint) TO staff;


--
-- Name: FUNCTION feature_overlaps(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.feature_overlaps(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.feature_overlaps(bigint) FROM www;
GRANT ALL ON FUNCTION chado.feature_overlaps(bigint) TO www;
GRANT ALL ON FUNCTION chado.feature_overlaps(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.feature_overlaps(bigint) TO staff;


--
-- Name: TABLE featureloc; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureloc FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureloc FROM www;
GRANT ALL ON TABLE chado.featureloc TO www;
GRANT ALL ON TABLE chado.featureloc TO staff;


--
-- Name: FUNCTION feature_subalignments(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.feature_subalignments(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.feature_subalignments(integer) FROM www;
GRANT ALL ON FUNCTION chado.feature_subalignments(integer) TO www;
GRANT ALL ON FUNCTION chado.feature_subalignments(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.feature_subalignments(integer) TO staff;


--
-- Name: FUNCTION featureloc_slice(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.featureloc_slice(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.featureloc_slice(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint) TO staff;


--
-- Name: FUNCTION featureloc_slice(integer, bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.featureloc_slice(integer, bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.featureloc_slice(integer, bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.featureloc_slice(integer, bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.featureloc_slice(integer, bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.featureloc_slice(integer, bigint, bigint) TO staff;


--
-- Name: FUNCTION featureloc_slice(bigint, bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.featureloc_slice(bigint, bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.featureloc_slice(bigint, bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.featureloc_slice(bigint, bigint, bigint) TO staff;


--
-- Name: FUNCTION featureloc_slice(character varying, bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.featureloc_slice(character varying, bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.featureloc_slice(character varying, bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.featureloc_slice(character varying, bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.featureloc_slice(character varying, bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.featureloc_slice(character varying, bigint, bigint) TO staff;


--
-- Name: FUNCTION featureslice(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.featureslice(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.featureslice(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.featureslice(integer, integer) TO www;
GRANT ALL ON FUNCTION chado.featureslice(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.featureslice(integer, integer) TO staff;


--
-- Name: FUNCTION fill_cvtermpath(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.fill_cvtermpath(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.fill_cvtermpath(bigint) FROM www;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(bigint) TO www;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(bigint) TO staff;


--
-- Name: FUNCTION fill_cvtermpath(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.fill_cvtermpath(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.fill_cvtermpath(character varying) FROM www;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(character varying) TO www;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.fill_cvtermpath(character varying) TO staff;


--
-- Name: FUNCTION get_all_object_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_all_object_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_all_object_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_all_object_ids(integer) TO www;
GRANT ALL ON FUNCTION chado.get_all_object_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_all_object_ids(integer) TO staff;


--
-- Name: FUNCTION get_all_subject_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_all_subject_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_all_subject_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_all_subject_ids(integer) TO www;
GRANT ALL ON FUNCTION chado.get_all_subject_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_all_subject_ids(integer) TO staff;


--
-- Name: FUNCTION get_cv_id_for_feature(); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cv_id_for_feature() FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cv_id_for_feature() FROM www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature() TO www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature() TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature() TO staff;


--
-- Name: FUNCTION get_cv_id_for_feature_relationsgip(); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cv_id_for_feature_relationsgip() FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cv_id_for_feature_relationsgip() FROM www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature_relationsgip() TO www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature_relationsgip() TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cv_id_for_feature_relationsgip() TO staff;


--
-- Name: FUNCTION get_cv_id_for_featureprop(); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cv_id_for_featureprop() FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cv_id_for_featureprop() FROM www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_featureprop() TO www;
GRANT ALL ON FUNCTION chado.get_cv_id_for_featureprop() TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cv_id_for_featureprop() TO staff;


--
-- Name: FUNCTION get_cycle_cvterm_id(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer) TO www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer) TO staff;


--
-- Name: FUNCTION get_cycle_cvterm_id(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(character varying) TO staff;


--
-- Name: FUNCTION get_cycle_cvterm_id(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_id(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer, integer) TO www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_id(integer, integer) TO staff;


--
-- Name: FUNCTION get_cycle_cvterm_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_cycle_cvterm_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_ids(integer) TO www;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_cycle_cvterm_ids(integer) TO staff;


--
-- Name: FUNCTION get_feature_id(character varying, character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_id(character varying, character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_id(character varying, character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_id(character varying, character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_id(character varying, character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_id(character varying, character varying, character varying) TO staff;


--
-- Name: FUNCTION get_feature_ids(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids(text) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids(text) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids(text) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_child_count(character varying, character varying, integer, character varying, character) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_ont(character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont(character varying, character varying) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_ont_root(character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_ont_root(character varying, character varying) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_property(character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_property(character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_property(character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_property(character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_property(character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_property(character varying, character varying) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_propval(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_propval(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_propval(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_propval(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_propval(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_propval(character varying) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_type(character varying, character); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type(character varying, character) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type(character varying, character) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type(character varying, character) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type(character varying, character) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type(character varying, character) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_type_name(character varying, text, character); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_name(character varying, text, character) TO staff;


--
-- Name: FUNCTION get_feature_ids_by_type_src(character varying, text, character); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) TO www;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_ids_by_type_src(character varying, text, character) TO staff;


--
-- Name: FUNCTION get_feature_relationship_type_id(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_relationship_type_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_relationship_type_id(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_relationship_type_id(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_relationship_type_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_relationship_type_id(character varying) TO staff;


--
-- Name: FUNCTION get_feature_type_id(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_feature_type_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_feature_type_id(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_feature_type_id(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_feature_type_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_feature_type_id(character varying) TO staff;


--
-- Name: FUNCTION get_featureprop_type_id(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_featureprop_type_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_featureprop_type_id(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_featureprop_type_id(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_featureprop_type_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_featureprop_type_id(character varying) TO staff;


--
-- Name: FUNCTION get_graph_above(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_graph_above(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_graph_above(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_graph_above(integer) TO www;
GRANT ALL ON FUNCTION chado.get_graph_above(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_graph_above(integer) TO staff;


--
-- Name: FUNCTION get_graph_below(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_graph_below(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_graph_below(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_graph_below(integer) TO www;
GRANT ALL ON FUNCTION chado.get_graph_below(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_graph_below(integer) TO staff;


--
-- Name: TABLE cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvterm FROM www;
GRANT ALL ON TABLE chado.cvterm TO www;
GRANT ALL ON TABLE chado.cvterm TO staff;


--
-- Name: FUNCTION get_it_sub_cvterm_ids(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_it_sub_cvterm_ids(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_it_sub_cvterm_ids(text) FROM www;
GRANT ALL ON FUNCTION chado.get_it_sub_cvterm_ids(text) TO www;
GRANT ALL ON FUNCTION chado.get_it_sub_cvterm_ids(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_it_sub_cvterm_ids(text) TO staff;


--
-- Name: FUNCTION get_organism_id(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_organism_id(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_organism_id(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying) TO staff;


--
-- Name: FUNCTION get_organism_id(character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_organism_id(character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_organism_id(character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_organism_id(character varying, character varying) TO staff;


--
-- Name: FUNCTION get_organism_id_abbrev(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_organism_id_abbrev(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_organism_id_abbrev(character varying) FROM www;
GRANT ALL ON FUNCTION chado.get_organism_id_abbrev(character varying) TO www;
GRANT ALL ON FUNCTION chado.get_organism_id_abbrev(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_organism_id_abbrev(character varying) TO staff;


--
-- Name: FUNCTION get_sub_feature_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer) TO www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer) TO staff;


--
-- Name: FUNCTION get_sub_feature_ids(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(text) FROM www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(text) TO www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(text) TO staff;


--
-- Name: FUNCTION get_sub_feature_ids(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_sub_feature_ids(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer, integer) TO www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids(integer, integer) TO staff;


--
-- Name: FUNCTION get_sub_feature_ids_by_type_src(character varying, text, character); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) FROM www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) TO www;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_sub_feature_ids_by_type_src(character varying, text, character) TO staff;


--
-- Name: FUNCTION get_up_feature_ids(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_up_feature_ids(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_up_feature_ids(integer) FROM www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer) TO www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer) TO staff;


--
-- Name: FUNCTION get_up_feature_ids(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_up_feature_ids(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_up_feature_ids(text) FROM www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(text) TO www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(text) TO staff;


--
-- Name: FUNCTION get_up_feature_ids(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.get_up_feature_ids(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.get_up_feature_ids(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer, integer) TO www;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.get_up_feature_ids(integer, integer) TO staff;


--
-- Name: FUNCTION gffattstring(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.gffattstring(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.gffattstring(integer) FROM www;
GRANT ALL ON FUNCTION chado.gffattstring(integer) TO www;
GRANT ALL ON FUNCTION chado.gffattstring(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.gffattstring(integer) TO staff;


--
-- Name: TABLE db; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.db FROM PUBLIC;
REVOKE ALL ON TABLE chado.db FROM www;
GRANT ALL ON TABLE chado.db TO www;
GRANT ALL ON TABLE chado.db TO staff;


--
-- Name: TABLE dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.dbxref FROM www;
GRANT ALL ON TABLE chado.dbxref TO www;
GRANT ALL ON TABLE chado.dbxref TO staff;


--
-- Name: TABLE feature_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_cvterm FROM www;
GRANT ALL ON TABLE chado.feature_cvterm TO www;
GRANT ALL ON TABLE chado.feature_cvterm TO staff;


--
-- Name: TABLE feature_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_dbxref FROM www;
GRANT ALL ON TABLE chado.feature_dbxref TO www;
GRANT ALL ON TABLE chado.feature_dbxref TO staff;


--
-- Name: TABLE feature_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_pub FROM www;
GRANT ALL ON TABLE chado.feature_pub TO www;
GRANT ALL ON TABLE chado.feature_pub TO staff;


--
-- Name: TABLE feature_synonym; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_synonym FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_synonym FROM www;
GRANT ALL ON TABLE chado.feature_synonym TO www;
GRANT ALL ON TABLE chado.feature_synonym TO staff;


--
-- Name: TABLE featureprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureprop FROM www;
GRANT ALL ON TABLE chado.featureprop TO www;
GRANT ALL ON TABLE chado.featureprop TO staff;


--
-- Name: TABLE pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.pub FROM www;
GRANT ALL ON TABLE chado.pub TO www;
GRANT ALL ON TABLE chado.pub TO staff;


--
-- Name: TABLE synonym; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.synonym FROM PUBLIC;
REVOKE ALL ON TABLE chado.synonym FROM www;
GRANT ALL ON TABLE chado.synonym TO www;
GRANT ALL ON TABLE chado.synonym TO staff;


--
-- Name: TABLE gffatts; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.gffatts FROM PUBLIC;
REVOKE ALL ON TABLE chado.gffatts FROM www;
GRANT ALL ON TABLE chado.gffatts TO www;
GRANT ALL ON TABLE chado.gffatts TO staff;


--
-- Name: FUNCTION gfffeatureatts(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.gfffeatureatts(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.gfffeatureatts(integer) FROM www;
GRANT ALL ON FUNCTION chado.gfffeatureatts(integer) TO www;
GRANT ALL ON FUNCTION chado.gfffeatureatts(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.gfffeatureatts(integer) TO staff;


--
-- Name: FUNCTION order_exons(integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.order_exons(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.order_exons(integer) FROM www;
GRANT ALL ON FUNCTION chado.order_exons(integer) TO www;
GRANT ALL ON FUNCTION chado.order_exons(integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.order_exons(integer) TO staff;


--
-- Name: FUNCTION phylonode_depth(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.phylonode_depth(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.phylonode_depth(bigint) FROM www;
GRANT ALL ON FUNCTION chado.phylonode_depth(bigint) TO www;
GRANT ALL ON FUNCTION chado.phylonode_depth(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.phylonode_depth(bigint) TO staff;


--
-- Name: FUNCTION phylonode_height(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.phylonode_height(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.phylonode_height(bigint) FROM www;
GRANT ALL ON FUNCTION chado.phylonode_height(bigint) TO www;
GRANT ALL ON FUNCTION chado.phylonode_height(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.phylonode_height(bigint) TO staff;


--
-- Name: FUNCTION project_featureloc_up(integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.project_featureloc_up(integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.project_featureloc_up(integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.project_featureloc_up(integer, integer) TO www;
GRANT ALL ON FUNCTION chado.project_featureloc_up(integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.project_featureloc_up(integer, integer) TO staff;


--
-- Name: FUNCTION project_point_down(integer, integer, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.project_point_down(integer, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.project_point_down(integer, integer, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.project_point_down(integer, integer, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.project_point_down(integer, integer, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.project_point_down(integer, integer, integer, integer) TO staff;


--
-- Name: FUNCTION project_point_g2t(integer, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.project_point_g2t(integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.project_point_g2t(integer, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.project_point_g2t(integer, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.project_point_g2t(integer, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.project_point_g2t(integer, integer, integer) TO staff;


--
-- Name: FUNCTION project_point_up(integer, integer, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.project_point_up(integer, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.project_point_up(integer, integer, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.project_point_up(integer, integer, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.project_point_up(integer, integer, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.project_point_up(integer, integer, integer, integer) TO staff;


--
-- Name: FUNCTION reverse_complement(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.reverse_complement(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.reverse_complement(text) FROM www;
GRANT ALL ON FUNCTION chado.reverse_complement(text) TO www;
GRANT ALL ON FUNCTION chado.reverse_complement(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.reverse_complement(text) TO staff;


--
-- Name: FUNCTION reverse_string(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.reverse_string(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.reverse_string(text) FROM www;
GRANT ALL ON FUNCTION chado.reverse_string(text) TO www;
GRANT ALL ON FUNCTION chado.reverse_string(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.reverse_string(text) TO staff;


--
-- Name: FUNCTION search_columns(needle text, haystack_tables name[], haystack_schema name[]); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) FROM www;
GRANT ALL ON FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) TO www;
GRANT ALL ON FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) TO PUBLIC;
GRANT ALL ON FUNCTION chado.search_columns(needle text, haystack_tables name[], haystack_schema name[]) TO staff;


--
-- Name: FUNCTION set_secondary_marker_pub(integer, text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.set_secondary_marker_pub(integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.set_secondary_marker_pub(integer, text) FROM www;
GRANT ALL ON FUNCTION chado.set_secondary_marker_pub(integer, text) TO www;
GRANT ALL ON FUNCTION chado.set_secondary_marker_pub(integer, text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.set_secondary_marker_pub(integer, text) TO staff;


--
-- Name: FUNCTION share_exons(); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.share_exons() FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.share_exons() FROM www;
GRANT ALL ON FUNCTION chado.share_exons() TO www;
GRANT ALL ON FUNCTION chado.share_exons() TO PUBLIC;
GRANT ALL ON FUNCTION chado.share_exons() TO staff;


--
-- Name: FUNCTION store_analysis(character varying, character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_analysis(character varying, character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_analysis(character varying, character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.store_analysis(character varying, character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.store_analysis(character varying, character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_analysis(character varying, character varying, character varying) TO staff;


--
-- Name: FUNCTION store_db(character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_db(character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_db(character varying) FROM www;
GRANT ALL ON FUNCTION chado.store_db(character varying) TO www;
GRANT ALL ON FUNCTION chado.store_db(character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_db(character varying) TO staff;


--
-- Name: FUNCTION store_dbxref(character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_dbxref(character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_dbxref(character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.store_dbxref(character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.store_dbxref(character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_dbxref(character varying, character varying) TO staff;


--
-- Name: FUNCTION store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) FROM www;
GRANT ALL ON FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) TO www;
GRANT ALL ON FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_feature(integer, integer, integer, integer, integer, integer, character varying, character varying, integer, boolean) TO staff;


--
-- Name: FUNCTION store_feature_synonym(integer, character varying, integer, boolean, boolean, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) FROM www;
GRANT ALL ON FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) TO www;
GRANT ALL ON FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_feature_synonym(integer, character varying, integer, boolean, boolean, integer) TO staff;


--
-- Name: FUNCTION store_featureloc(integer, integer, integer, integer, integer, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_featureloc(integer, integer, integer, integer, integer, integer, integer) TO staff;


--
-- Name: FUNCTION store_organism(character varying, character varying, character varying); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.store_organism(character varying, character varying, character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.store_organism(character varying, character varying, character varying) FROM www;
GRANT ALL ON FUNCTION chado.store_organism(character varying, character varying, character varying) TO www;
GRANT ALL ON FUNCTION chado.store_organism(character varying, character varying, character varying) TO PUBLIC;
GRANT ALL ON FUNCTION chado.store_organism(character varying, character varying, character varying) TO staff;


--
-- Name: FUNCTION subsequence(bigint, bigint, bigint, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence(bigint, bigint, bigint, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence(bigint, bigint, bigint, integer) FROM www;
GRANT ALL ON FUNCTION chado.subsequence(bigint, bigint, bigint, integer) TO www;
GRANT ALL ON FUNCTION chado.subsequence(bigint, bigint, bigint, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence(bigint, bigint, bigint, integer) TO staff;


--
-- Name: FUNCTION subsequence_by_feature(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_feature(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_feature(bigint) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint) TO staff;


--
-- Name: FUNCTION subsequence_by_feature(bigint, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_feature(bigint, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_feature(bigint, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_feature(bigint, integer, integer) TO staff;


--
-- Name: FUNCTION subsequence_by_featureloc(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_featureloc(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_featureloc(bigint) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_featureloc(bigint) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_featureloc(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_featureloc(bigint) TO staff;


--
-- Name: FUNCTION subsequence_by_subfeatures(bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint) TO staff;


--
-- Name: FUNCTION subsequence_by_subfeatures(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint) TO staff;


--
-- Name: FUNCTION subsequence_by_subfeatures(bigint, bigint, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_subfeatures(bigint, bigint, integer, integer) TO staff;


--
-- Name: FUNCTION subsequence_by_typed_subfeatures(bigint, bigint); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint) TO staff;


--
-- Name: FUNCTION subsequence_by_typed_subfeatures(bigint, bigint, integer, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) FROM www;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) TO www;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.subsequence_by_typed_subfeatures(bigint, bigint, integer, integer) TO staff;


--
-- Name: FUNCTION translate_codon(text, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.translate_codon(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.translate_codon(text, integer) FROM www;
GRANT ALL ON FUNCTION chado.translate_codon(text, integer) TO www;
GRANT ALL ON FUNCTION chado.translate_codon(text, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.translate_codon(text, integer) TO staff;


--
-- Name: FUNCTION translate_dna(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.translate_dna(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.translate_dna(text) FROM www;
GRANT ALL ON FUNCTION chado.translate_dna(text) TO www;
GRANT ALL ON FUNCTION chado.translate_dna(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.translate_dna(text) TO staff;


--
-- Name: FUNCTION translate_dna(text, integer); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.translate_dna(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.translate_dna(text, integer) FROM www;
GRANT ALL ON FUNCTION chado.translate_dna(text, integer) TO www;
GRANT ALL ON FUNCTION chado.translate_dna(text, integer) TO PUBLIC;
GRANT ALL ON FUNCTION chado.translate_dna(text, integer) TO staff;


--
-- Name: FUNCTION concat(text); Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON FUNCTION chado.concat(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION chado.concat(text) FROM www;
GRANT ALL ON FUNCTION chado.concat(text) TO www;
GRANT ALL ON FUNCTION chado.concat(text) TO PUBLIC;
GRANT ALL ON FUNCTION chado.concat(text) TO staff;


--
-- Name: TABLE acquisition; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.acquisition FROM PUBLIC;
REVOKE ALL ON TABLE chado.acquisition FROM www;
GRANT ALL ON TABLE chado.acquisition TO www;
GRANT ALL ON TABLE chado.acquisition TO staff;


--
-- Name: SEQUENCE acquisition_acquisition_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.acquisition_acquisition_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.acquisition_acquisition_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.acquisition_acquisition_id_seq TO www;
GRANT ALL ON SEQUENCE chado.acquisition_acquisition_id_seq TO staff;


--
-- Name: TABLE acquisition_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.acquisition_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.acquisition_relationship FROM www;
GRANT ALL ON TABLE chado.acquisition_relationship TO www;
GRANT ALL ON TABLE chado.acquisition_relationship TO staff;


--
-- Name: SEQUENCE acquisition_relationship_acquisition_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.acquisition_relationship_acquisition_relationship_id_seq TO staff;


--
-- Name: TABLE acquisitionprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.acquisitionprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.acquisitionprop FROM www;
GRANT ALL ON TABLE chado.acquisitionprop TO www;
GRANT ALL ON TABLE chado.acquisitionprop TO staff;


--
-- Name: SEQUENCE acquisitionprop_acquisitionprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.acquisitionprop_acquisitionprop_id_seq TO staff;


--
-- Name: TABLE all_feature_names; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.all_feature_names FROM PUBLIC;
REVOKE ALL ON TABLE chado.all_feature_names FROM www;
GRANT ALL ON TABLE chado.all_feature_names TO www;
GRANT ALL ON TABLE chado.all_feature_names TO staff;


--
-- Name: TABLE analysis; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis FROM www;
GRANT ALL ON TABLE chado.analysis TO www;
GRANT ALL ON TABLE chado.analysis TO staff;


--
-- Name: SEQUENCE analysis_analysis_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysis_analysis_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysis_analysis_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysis_analysis_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysis_analysis_id_seq TO staff;


--
-- Name: TABLE analysis_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis_cvterm FROM www;
GRANT ALL ON TABLE chado.analysis_cvterm TO www;
GRANT ALL ON TABLE chado.analysis_cvterm TO staff;


--
-- Name: SEQUENCE analysis_cvterm_analysis_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysis_cvterm_analysis_cvterm_id_seq TO staff;


--
-- Name: TABLE analysis_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis_dbxref FROM www;
GRANT ALL ON TABLE chado.analysis_dbxref TO www;
GRANT ALL ON TABLE chado.analysis_dbxref TO staff;


--
-- Name: SEQUENCE analysis_dbxref_analysis_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysis_dbxref_analysis_dbxref_id_seq TO staff;


--
-- Name: TABLE analysis_organism; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis_organism FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis_organism FROM www;
GRANT ALL ON TABLE chado.analysis_organism TO www;
GRANT ALL ON TABLE chado.analysis_organism TO staff;


--
-- Name: TABLE analysis_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis_pub FROM www;
GRANT ALL ON TABLE chado.analysis_pub TO www;
GRANT ALL ON TABLE chado.analysis_pub TO staff;


--
-- Name: SEQUENCE analysis_pub_analysis_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysis_pub_analysis_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysis_pub_analysis_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysis_pub_analysis_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysis_pub_analysis_pub_id_seq TO staff;


--
-- Name: TABLE analysis_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysis_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysis_relationship FROM www;
GRANT ALL ON TABLE chado.analysis_relationship TO www;
GRANT ALL ON TABLE chado.analysis_relationship TO staff;


--
-- Name: SEQUENCE analysis_relationship_analysis_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysis_relationship_analysis_relationship_id_seq TO staff;


--
-- Name: TABLE analysisfeature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysisfeature FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysisfeature FROM www;
GRANT ALL ON TABLE chado.analysisfeature TO www;
GRANT ALL ON TABLE chado.analysisfeature TO staff;


--
-- Name: SEQUENCE analysisfeature_analysisfeature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysisfeature_analysisfeature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysisfeature_analysisfeature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysisfeature_analysisfeature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysisfeature_analysisfeature_id_seq TO staff;


--
-- Name: TABLE analysisfeatureprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysisfeatureprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysisfeatureprop FROM www;
GRANT ALL ON TABLE chado.analysisfeatureprop TO www;
GRANT ALL ON TABLE chado.analysisfeatureprop TO staff;


--
-- Name: SEQUENCE analysisfeatureprop_analysisfeatureprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysisfeatureprop_analysisfeatureprop_id_seq TO staff;


--
-- Name: TABLE analysisprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.analysisprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.analysisprop FROM www;
GRANT ALL ON TABLE chado.analysisprop TO www;
GRANT ALL ON TABLE chado.analysisprop TO staff;


--
-- Name: SEQUENCE analysisprop_analysisprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.analysisprop_analysisprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.analysisprop_analysisprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.analysisprop_analysisprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.analysisprop_analysisprop_id_seq TO staff;


--
-- Name: TABLE arraydesign; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.arraydesign FROM PUBLIC;
REVOKE ALL ON TABLE chado.arraydesign FROM www;
GRANT ALL ON TABLE chado.arraydesign TO www;
GRANT ALL ON TABLE chado.arraydesign TO staff;


--
-- Name: SEQUENCE arraydesign_arraydesign_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.arraydesign_arraydesign_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.arraydesign_arraydesign_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.arraydesign_arraydesign_id_seq TO www;
GRANT ALL ON SEQUENCE chado.arraydesign_arraydesign_id_seq TO staff;


--
-- Name: TABLE arraydesignprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.arraydesignprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.arraydesignprop FROM www;
GRANT ALL ON TABLE chado.arraydesignprop TO www;
GRANT ALL ON TABLE chado.arraydesignprop TO staff;


--
-- Name: SEQUENCE arraydesignprop_arraydesignprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.arraydesignprop_arraydesignprop_id_seq TO staff;


--
-- Name: TABLE assay; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.assay FROM PUBLIC;
REVOKE ALL ON TABLE chado.assay FROM www;
GRANT ALL ON TABLE chado.assay TO www;
GRANT ALL ON TABLE chado.assay TO staff;


--
-- Name: SEQUENCE assay_assay_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.assay_assay_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.assay_assay_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.assay_assay_id_seq TO www;
GRANT ALL ON SEQUENCE chado.assay_assay_id_seq TO staff;


--
-- Name: TABLE assay_biomaterial; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.assay_biomaterial FROM PUBLIC;
REVOKE ALL ON TABLE chado.assay_biomaterial FROM www;
GRANT ALL ON TABLE chado.assay_biomaterial TO www;
GRANT ALL ON TABLE chado.assay_biomaterial TO staff;


--
-- Name: SEQUENCE assay_biomaterial_assay_biomaterial_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq TO www;
GRANT ALL ON SEQUENCE chado.assay_biomaterial_assay_biomaterial_id_seq TO staff;


--
-- Name: TABLE assay_project; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.assay_project FROM PUBLIC;
REVOKE ALL ON TABLE chado.assay_project FROM www;
GRANT ALL ON TABLE chado.assay_project TO www;
GRANT ALL ON TABLE chado.assay_project TO staff;


--
-- Name: SEQUENCE assay_project_assay_project_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.assay_project_assay_project_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.assay_project_assay_project_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.assay_project_assay_project_id_seq TO www;
GRANT ALL ON SEQUENCE chado.assay_project_assay_project_id_seq TO staff;


--
-- Name: TABLE assayprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.assayprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.assayprop FROM www;
GRANT ALL ON TABLE chado.assayprop TO www;
GRANT ALL ON TABLE chado.assayprop TO staff;


--
-- Name: SEQUENCE assayprop_assayprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.assayprop_assayprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.assayprop_assayprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.assayprop_assayprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.assayprop_assayprop_id_seq TO staff;


--
-- Name: TABLE biomaterial; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.biomaterial FROM PUBLIC;
REVOKE ALL ON TABLE chado.biomaterial FROM www;
GRANT ALL ON TABLE chado.biomaterial TO www;
GRANT ALL ON TABLE chado.biomaterial TO staff;


--
-- Name: SEQUENCE biomaterial_biomaterial_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.biomaterial_biomaterial_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.biomaterial_biomaterial_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.biomaterial_biomaterial_id_seq TO www;
GRANT ALL ON SEQUENCE chado.biomaterial_biomaterial_id_seq TO staff;


--
-- Name: TABLE biomaterial_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.biomaterial_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.biomaterial_dbxref FROM www;
GRANT ALL ON TABLE chado.biomaterial_dbxref TO www;
GRANT ALL ON TABLE chado.biomaterial_dbxref TO staff;


--
-- Name: SEQUENCE biomaterial_dbxref_biomaterial_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.biomaterial_dbxref_biomaterial_dbxref_id_seq TO staff;


--
-- Name: TABLE biomaterial_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.biomaterial_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.biomaterial_relationship FROM www;
GRANT ALL ON TABLE chado.biomaterial_relationship TO www;
GRANT ALL ON TABLE chado.biomaterial_relationship TO staff;


--
-- Name: SEQUENCE biomaterial_relationship_biomaterial_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.biomaterial_relationship_biomaterial_relationship_id_seq TO staff;


--
-- Name: TABLE biomaterial_treatment; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.biomaterial_treatment FROM PUBLIC;
REVOKE ALL ON TABLE chado.biomaterial_treatment FROM www;
GRANT ALL ON TABLE chado.biomaterial_treatment TO www;
GRANT ALL ON TABLE chado.biomaterial_treatment TO staff;


--
-- Name: SEQUENCE biomaterial_treatment_biomaterial_treatment_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq TO www;
GRANT ALL ON SEQUENCE chado.biomaterial_treatment_biomaterial_treatment_id_seq TO staff;


--
-- Name: TABLE biomaterialprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.biomaterialprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.biomaterialprop FROM www;
GRANT ALL ON TABLE chado.biomaterialprop TO www;
GRANT ALL ON TABLE chado.biomaterialprop TO staff;


--
-- Name: SEQUENCE biomaterialprop_biomaterialprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.biomaterialprop_biomaterialprop_id_seq TO staff;


--
-- Name: TABLE blast_hit_data; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.blast_hit_data FROM PUBLIC;
REVOKE ALL ON TABLE chado.blast_hit_data FROM www;
GRANT ALL ON TABLE chado.blast_hit_data TO www;
GRANT ALL ON TABLE chado.blast_hit_data TO staff;


--
-- Name: TABLE blast_organisms; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.blast_organisms FROM PUBLIC;
REVOKE ALL ON TABLE chado.blast_organisms FROM www;
GRANT ALL ON TABLE chado.blast_organisms TO www;
GRANT ALL ON TABLE chado.blast_organisms TO staff;


--
-- Name: SEQUENCE blast_organisms_blast_org_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.blast_organisms_blast_org_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.blast_organisms_blast_org_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.blast_organisms_blast_org_id_seq TO www;
GRANT ALL ON SEQUENCE chado.blast_organisms_blast_org_id_seq TO staff;


--
-- Name: TABLE cell_line; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line FROM www;
GRANT ALL ON TABLE chado.cell_line TO www;
GRANT ALL ON TABLE chado.cell_line TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line TO staff;


--
-- Name: SEQUENCE cell_line_cell_line_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_cell_line_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_cell_line_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_cell_line_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_cell_line_id_seq TO staff;


--
-- Name: TABLE cell_line_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_cvterm FROM www;
GRANT ALL ON TABLE chado.cell_line_cvterm TO www;
GRANT ALL ON TABLE chado.cell_line_cvterm TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_cvterm TO staff;


--
-- Name: SEQUENCE cell_line_cvterm_cell_line_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_cvterm_cell_line_cvterm_id_seq TO staff;


--
-- Name: TABLE cell_line_cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_cvtermprop FROM www;
GRANT ALL ON TABLE chado.cell_line_cvtermprop TO www;
GRANT ALL ON TABLE chado.cell_line_cvtermprop TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_cvtermprop TO staff;


--
-- Name: SEQUENCE cell_line_cvtermprop_cell_line_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_cvtermprop_cell_line_cvtermprop_id_seq TO staff;


--
-- Name: TABLE cell_line_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_dbxref FROM www;
GRANT ALL ON TABLE chado.cell_line_dbxref TO www;
GRANT ALL ON TABLE chado.cell_line_dbxref TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_dbxref TO staff;


--
-- Name: SEQUENCE cell_line_dbxref_cell_line_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_dbxref_cell_line_dbxref_id_seq TO staff;


--
-- Name: TABLE cell_line_feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_feature FROM www;
GRANT ALL ON TABLE chado.cell_line_feature TO www;
GRANT ALL ON TABLE chado.cell_line_feature TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_feature TO staff;


--
-- Name: SEQUENCE cell_line_feature_cell_line_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_feature_cell_line_feature_id_seq TO staff;


--
-- Name: TABLE cell_line_library; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_library FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_library FROM www;
GRANT ALL ON TABLE chado.cell_line_library TO www;
GRANT ALL ON TABLE chado.cell_line_library TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_library TO staff;


--
-- Name: SEQUENCE cell_line_library_cell_line_library_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_library_cell_line_library_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_library_cell_line_library_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_library_cell_line_library_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_library_cell_line_library_id_seq TO staff;


--
-- Name: TABLE cell_line_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_pub FROM www;
GRANT ALL ON TABLE chado.cell_line_pub TO www;
GRANT ALL ON TABLE chado.cell_line_pub TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_pub TO staff;


--
-- Name: SEQUENCE cell_line_pub_cell_line_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_pub_cell_line_pub_id_seq TO staff;


--
-- Name: TABLE cell_line_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_relationship FROM www;
GRANT ALL ON TABLE chado.cell_line_relationship TO www;
GRANT ALL ON TABLE chado.cell_line_relationship TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_relationship TO staff;


--
-- Name: SEQUENCE cell_line_relationship_cell_line_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_relationship_cell_line_relationship_id_seq TO staff;


--
-- Name: TABLE cell_line_synonym; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_line_synonym FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_line_synonym FROM www;
GRANT ALL ON TABLE chado.cell_line_synonym TO www;
GRANT ALL ON TABLE chado.cell_line_synonym TO PUBLIC;
GRANT ALL ON TABLE chado.cell_line_synonym TO staff;


--
-- Name: SEQUENCE cell_line_synonym_cell_line_synonym_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_line_synonym_cell_line_synonym_id_seq TO staff;


--
-- Name: TABLE cell_lineprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_lineprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_lineprop FROM www;
GRANT ALL ON TABLE chado.cell_lineprop TO www;
GRANT ALL ON TABLE chado.cell_lineprop TO PUBLIC;
GRANT ALL ON TABLE chado.cell_lineprop TO staff;


--
-- Name: SEQUENCE cell_lineprop_cell_lineprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_lineprop_cell_lineprop_id_seq TO staff;


--
-- Name: TABLE cell_lineprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cell_lineprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.cell_lineprop_pub FROM www;
GRANT ALL ON TABLE chado.cell_lineprop_pub TO www;
GRANT ALL ON TABLE chado.cell_lineprop_pub TO PUBLIC;
GRANT ALL ON TABLE chado.cell_lineprop_pub TO staff;


--
-- Name: SEQUENCE cell_lineprop_pub_cell_lineprop_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cell_lineprop_pub_cell_lineprop_pub_id_seq TO staff;


--
-- Name: TABLE chadoprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.chadoprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.chadoprop FROM www;
GRANT ALL ON TABLE chado.chadoprop TO www;
GRANT ALL ON TABLE chado.chadoprop TO staff;


--
-- Name: SEQUENCE chadoprop_chadoprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.chadoprop_chadoprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.chadoprop_chadoprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.chadoprop_chadoprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.chadoprop_chadoprop_id_seq TO staff;


--
-- Name: TABLE channel; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.channel FROM PUBLIC;
REVOKE ALL ON TABLE chado.channel FROM www;
GRANT ALL ON TABLE chado.channel TO www;
GRANT ALL ON TABLE chado.channel TO staff;


--
-- Name: SEQUENCE channel_channel_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.channel_channel_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.channel_channel_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.channel_channel_id_seq TO www;
GRANT ALL ON SEQUENCE chado.channel_channel_id_seq TO staff;


--
-- Name: TABLE common_ancestor_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.common_ancestor_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.common_ancestor_cvterm FROM www;
GRANT ALL ON TABLE chado.common_ancestor_cvterm TO www;
GRANT ALL ON TABLE chado.common_ancestor_cvterm TO staff;


--
-- Name: TABLE common_descendant_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.common_descendant_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.common_descendant_cvterm FROM www;
GRANT ALL ON TABLE chado.common_descendant_cvterm TO www;
GRANT ALL ON TABLE chado.common_descendant_cvterm TO staff;


--
-- Name: TABLE contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.contact FROM www;
GRANT ALL ON TABLE chado.contact TO www;
GRANT ALL ON TABLE chado.contact TO staff;


--
-- Name: SEQUENCE contact_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.contact_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.contact_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.contact_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.contact_contact_id_seq TO staff;


--
-- Name: TABLE contact_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.contact_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.contact_relationship FROM www;
GRANT ALL ON TABLE chado.contact_relationship TO www;
GRANT ALL ON TABLE chado.contact_relationship TO staff;


--
-- Name: SEQUENCE contact_relationship_contact_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.contact_relationship_contact_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.contact_relationship_contact_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.contact_relationship_contact_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.contact_relationship_contact_relationship_id_seq TO staff;


--
-- Name: TABLE contactprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.contactprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.contactprop FROM www;
GRANT ALL ON TABLE chado.contactprop TO www;
GRANT ALL ON TABLE chado.contactprop TO staff;


--
-- Name: SEQUENCE contactprop_contactprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.contactprop_contactprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.contactprop_contactprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.contactprop_contactprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.contactprop_contactprop_id_seq TO staff;


--
-- Name: TABLE control; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.control FROM PUBLIC;
REVOKE ALL ON TABLE chado.control FROM www;
GRANT ALL ON TABLE chado.control TO www;
GRANT ALL ON TABLE chado.control TO staff;


--
-- Name: SEQUENCE control_control_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.control_control_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.control_control_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.control_control_id_seq TO www;
GRANT ALL ON SEQUENCE chado.control_control_id_seq TO staff;


--
-- Name: TABLE cv; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv FROM www;
GRANT ALL ON TABLE chado.cv TO www;
GRANT ALL ON TABLE chado.cv TO staff;


--
-- Name: SEQUENCE cv_cv_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cv_cv_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cv_cv_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cv_cv_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cv_cv_id_seq TO staff;


--
-- Name: TABLE cv_cvterm_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_cvterm_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_cvterm_count FROM www;
GRANT ALL ON TABLE chado.cv_cvterm_count TO www;
GRANT ALL ON TABLE chado.cv_cvterm_count TO staff;


--
-- Name: TABLE cv_cvterm_count_with_obs; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_cvterm_count_with_obs FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_cvterm_count_with_obs FROM www;
GRANT ALL ON TABLE chado.cv_cvterm_count_with_obs TO www;
GRANT ALL ON TABLE chado.cv_cvterm_count_with_obs TO staff;


--
-- Name: TABLE cvterm_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvterm_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvterm_relationship FROM www;
GRANT ALL ON TABLE chado.cvterm_relationship TO www;
GRANT ALL ON TABLE chado.cvterm_relationship TO staff;


--
-- Name: TABLE cv_leaf; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_leaf FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_leaf FROM www;
GRANT ALL ON TABLE chado.cv_leaf TO www;
GRANT ALL ON TABLE chado.cv_leaf TO staff;


--
-- Name: TABLE cv_link_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_link_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_link_count FROM www;
GRANT ALL ON TABLE chado.cv_link_count TO www;
GRANT ALL ON TABLE chado.cv_link_count TO staff;


--
-- Name: TABLE cv_path_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_path_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_path_count FROM www;
GRANT ALL ON TABLE chado.cv_path_count TO www;
GRANT ALL ON TABLE chado.cv_path_count TO staff;


--
-- Name: TABLE cv_root; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_root FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_root FROM www;
GRANT ALL ON TABLE chado.cv_root TO www;
GRANT ALL ON TABLE chado.cv_root TO staff;


--
-- Name: TABLE cv_root_mview; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cv_root_mview FROM PUBLIC;
REVOKE ALL ON TABLE chado.cv_root_mview FROM www;
GRANT ALL ON TABLE chado.cv_root_mview TO www;
GRANT ALL ON TABLE chado.cv_root_mview TO staff;


--
-- Name: TABLE cvprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvprop FROM www;
GRANT ALL ON TABLE chado.cvprop TO www;
GRANT ALL ON TABLE chado.cvprop TO staff;


--
-- Name: SEQUENCE cvprop_cvprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvprop_cvprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvprop_cvprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvprop_cvprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvprop_cvprop_id_seq TO staff;


--
-- Name: SEQUENCE cvterm_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvterm_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvterm_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvterm_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvterm_cvterm_id_seq TO staff;


--
-- Name: TABLE cvterm_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvterm_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvterm_dbxref FROM www;
GRANT ALL ON TABLE chado.cvterm_dbxref TO www;
GRANT ALL ON TABLE chado.cvterm_dbxref TO staff;


--
-- Name: SEQUENCE cvterm_dbxref_cvterm_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvterm_dbxref_cvterm_dbxref_id_seq TO staff;


--
-- Name: SEQUENCE cvterm_relationship_cvterm_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvterm_relationship_cvterm_relationship_id_seq TO staff;


--
-- Name: SEQUENCE cvtermpath_cvtermpath_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvtermpath_cvtermpath_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvtermpath_cvtermpath_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvtermpath_cvtermpath_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvtermpath_cvtermpath_id_seq TO staff;


--
-- Name: TABLE cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvtermprop FROM www;
GRANT ALL ON TABLE chado.cvtermprop TO www;
GRANT ALL ON TABLE chado.cvtermprop TO staff;


--
-- Name: SEQUENCE cvtermprop_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvtermprop_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvtermprop_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvtermprop_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvtermprop_cvtermprop_id_seq TO staff;


--
-- Name: TABLE cvtermsynonym; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.cvtermsynonym FROM PUBLIC;
REVOKE ALL ON TABLE chado.cvtermsynonym FROM www;
GRANT ALL ON TABLE chado.cvtermsynonym TO www;
GRANT ALL ON TABLE chado.cvtermsynonym TO staff;


--
-- Name: SEQUENCE cvtermsynonym_cvtermsynonym_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq TO www;
GRANT ALL ON SEQUENCE chado.cvtermsynonym_cvtermsynonym_id_seq TO staff;


--
-- Name: SEQUENCE db_db_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.db_db_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.db_db_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.db_db_id_seq TO www;
GRANT ALL ON SEQUENCE chado.db_db_id_seq TO staff;


--
-- Name: TABLE db_dbxref_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.db_dbxref_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.db_dbxref_count FROM www;
GRANT ALL ON TABLE chado.db_dbxref_count TO www;
GRANT ALL ON TABLE chado.db_dbxref_count TO staff;


--
-- Name: TABLE dbprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.dbprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.dbprop FROM www;
GRANT ALL ON TABLE chado.dbprop TO www;
GRANT ALL ON TABLE chado.dbprop TO staff;


--
-- Name: SEQUENCE dbprop_dbprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.dbprop_dbprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.dbprop_dbprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.dbprop_dbprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.dbprop_dbprop_id_seq TO staff;


--
-- Name: SEQUENCE dbxref_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.dbxref_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.dbxref_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.dbxref_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.dbxref_dbxref_id_seq TO staff;


--
-- Name: TABLE dbxrefprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.dbxrefprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.dbxrefprop FROM www;
GRANT ALL ON TABLE chado.dbxrefprop TO www;
GRANT ALL ON TABLE chado.dbxrefprop TO staff;


--
-- Name: SEQUENCE dbxrefprop_dbxrefprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.dbxrefprop_dbxrefprop_id_seq TO staff;


--
-- Name: TABLE dfeatureloc; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.dfeatureloc FROM PUBLIC;
REVOKE ALL ON TABLE chado.dfeatureloc FROM www;
GRANT ALL ON TABLE chado.dfeatureloc TO www;
GRANT ALL ON TABLE chado.dfeatureloc TO staff;


--
-- Name: TABLE domain; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.domain FROM PUBLIC;
REVOKE ALL ON TABLE chado.domain FROM www;
GRANT ALL ON TABLE chado.domain TO www;
GRANT ALL ON TABLE chado.domain TO staff;


--
-- Name: TABLE eimage; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.eimage FROM PUBLIC;
REVOKE ALL ON TABLE chado.eimage FROM www;
GRANT ALL ON TABLE chado.eimage TO www;
GRANT ALL ON TABLE chado.eimage TO staff;


--
-- Name: SEQUENCE eimage_eimage_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.eimage_eimage_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.eimage_eimage_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.eimage_eimage_id_seq TO www;
GRANT ALL ON SEQUENCE chado.eimage_eimage_id_seq TO staff;


--
-- Name: TABLE element; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.element FROM PUBLIC;
REVOKE ALL ON TABLE chado.element FROM www;
GRANT ALL ON TABLE chado.element TO www;
GRANT ALL ON TABLE chado.element TO staff;


--
-- Name: SEQUENCE element_element_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.element_element_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.element_element_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.element_element_id_seq TO www;
GRANT ALL ON SEQUENCE chado.element_element_id_seq TO staff;


--
-- Name: TABLE element_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.element_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.element_relationship FROM www;
GRANT ALL ON TABLE chado.element_relationship TO www;
GRANT ALL ON TABLE chado.element_relationship TO staff;


--
-- Name: SEQUENCE element_relationship_element_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.element_relationship_element_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.element_relationship_element_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.element_relationship_element_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.element_relationship_element_relationship_id_seq TO staff;


--
-- Name: TABLE elementresult; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.elementresult FROM PUBLIC;
REVOKE ALL ON TABLE chado.elementresult FROM www;
GRANT ALL ON TABLE chado.elementresult TO www;
GRANT ALL ON TABLE chado.elementresult TO staff;


--
-- Name: SEQUENCE elementresult_elementresult_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.elementresult_elementresult_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.elementresult_elementresult_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.elementresult_elementresult_id_seq TO www;
GRANT ALL ON SEQUENCE chado.elementresult_elementresult_id_seq TO staff;


--
-- Name: TABLE elementresult_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.elementresult_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.elementresult_relationship FROM www;
GRANT ALL ON TABLE chado.elementresult_relationship TO www;
GRANT ALL ON TABLE chado.elementresult_relationship TO staff;


--
-- Name: SEQUENCE elementresult_relationship_elementresult_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.elementresult_relationship_elementresult_relationship_id_seq TO staff;


--
-- Name: TABLE environment; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.environment FROM PUBLIC;
REVOKE ALL ON TABLE chado.environment FROM www;
GRANT ALL ON TABLE chado.environment TO www;
GRANT ALL ON TABLE chado.environment TO staff;


--
-- Name: TABLE environment_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.environment_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.environment_cvterm FROM www;
GRANT ALL ON TABLE chado.environment_cvterm TO www;
GRANT ALL ON TABLE chado.environment_cvterm TO staff;


--
-- Name: SEQUENCE environment_cvterm_environment_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.environment_cvterm_environment_cvterm_id_seq TO staff;


--
-- Name: SEQUENCE environment_environment_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.environment_environment_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.environment_environment_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.environment_environment_id_seq TO www;
GRANT ALL ON SEQUENCE chado.environment_environment_id_seq TO staff;


--
-- Name: TABLE expression; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expression FROM PUBLIC;
REVOKE ALL ON TABLE chado.expression FROM www;
GRANT ALL ON TABLE chado.expression TO www;
GRANT ALL ON TABLE chado.expression TO staff;


--
-- Name: TABLE expression_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expression_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.expression_cvterm FROM www;
GRANT ALL ON TABLE chado.expression_cvterm TO www;
GRANT ALL ON TABLE chado.expression_cvterm TO staff;


--
-- Name: SEQUENCE expression_cvterm_expression_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expression_cvterm_expression_cvterm_id_seq TO staff;


--
-- Name: TABLE expression_cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expression_cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.expression_cvtermprop FROM www;
GRANT ALL ON TABLE chado.expression_cvtermprop TO www;
GRANT ALL ON TABLE chado.expression_cvtermprop TO staff;


--
-- Name: SEQUENCE expression_cvtermprop_expression_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expression_cvtermprop_expression_cvtermprop_id_seq TO staff;


--
-- Name: SEQUENCE expression_expression_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expression_expression_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expression_expression_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expression_expression_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expression_expression_id_seq TO staff;


--
-- Name: TABLE expression_image; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expression_image FROM PUBLIC;
REVOKE ALL ON TABLE chado.expression_image FROM www;
GRANT ALL ON TABLE chado.expression_image TO www;
GRANT ALL ON TABLE chado.expression_image TO staff;


--
-- Name: SEQUENCE expression_image_expression_image_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expression_image_expression_image_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expression_image_expression_image_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expression_image_expression_image_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expression_image_expression_image_id_seq TO staff;


--
-- Name: TABLE expression_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expression_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.expression_pub FROM www;
GRANT ALL ON TABLE chado.expression_pub TO www;
GRANT ALL ON TABLE chado.expression_pub TO staff;


--
-- Name: SEQUENCE expression_pub_expression_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expression_pub_expression_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expression_pub_expression_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expression_pub_expression_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expression_pub_expression_pub_id_seq TO staff;


--
-- Name: TABLE expressionprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.expressionprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.expressionprop FROM www;
GRANT ALL ON TABLE chado.expressionprop TO www;
GRANT ALL ON TABLE chado.expressionprop TO staff;


--
-- Name: SEQUENCE expressionprop_expressionprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.expressionprop_expressionprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.expressionprop_expressionprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.expressionprop_expressionprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.expressionprop_expressionprop_id_seq TO staff;


--
-- Name: TABLE f_type; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.f_type FROM PUBLIC;
REVOKE ALL ON TABLE chado.f_type FROM www;
GRANT ALL ON TABLE chado.f_type TO www;
GRANT ALL ON TABLE chado.f_type TO staff;


--
-- Name: TABLE f_loc; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.f_loc FROM PUBLIC;
REVOKE ALL ON TABLE chado.f_loc FROM www;
GRANT ALL ON TABLE chado.f_loc TO www;
GRANT ALL ON TABLE chado.f_loc TO staff;


--
-- Name: TABLE feature_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_contact FROM www;
GRANT ALL ON TABLE chado.feature_contact TO www;
GRANT ALL ON TABLE chado.feature_contact TO staff;


--
-- Name: SEQUENCE feature_contact_feature_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_contact_feature_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_contact_feature_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_contact_feature_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_contact_feature_contact_id_seq TO staff;


--
-- Name: TABLE feature_contains; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_contains FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_contains FROM www;
GRANT ALL ON TABLE chado.feature_contains TO www;
GRANT ALL ON TABLE chado.feature_contains TO staff;


--
-- Name: TABLE feature_cvterm_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_cvterm_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_cvterm_dbxref FROM www;
GRANT ALL ON TABLE chado.feature_cvterm_dbxref TO www;
GRANT ALL ON TABLE chado.feature_cvterm_dbxref TO staff;


--
-- Name: SEQUENCE feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_dbxref_feature_cvterm_dbxref_id_seq TO staff;


--
-- Name: SEQUENCE feature_cvterm_feature_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_feature_cvterm_id_seq TO staff;


--
-- Name: TABLE feature_cvterm_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_cvterm_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_cvterm_pub FROM www;
GRANT ALL ON TABLE chado.feature_cvterm_pub TO www;
GRANT ALL ON TABLE chado.feature_cvterm_pub TO staff;


--
-- Name: SEQUENCE feature_cvterm_pub_feature_cvterm_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_cvterm_pub_feature_cvterm_pub_id_seq TO staff;


--
-- Name: TABLE feature_cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_cvtermprop FROM www;
GRANT ALL ON TABLE chado.feature_cvtermprop TO www;
GRANT ALL ON TABLE chado.feature_cvtermprop TO staff;


--
-- Name: SEQUENCE feature_cvtermprop_feature_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_cvtermprop_feature_cvtermprop_id_seq TO staff;


--
-- Name: SEQUENCE feature_dbxref_feature_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_dbxref_feature_dbxref_id_seq TO staff;


--
-- Name: TABLE feature_difference; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_difference FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_difference FROM www;
GRANT ALL ON TABLE chado.feature_difference TO www;
GRANT ALL ON TABLE chado.feature_difference TO staff;


--
-- Name: TABLE feature_disjoint; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_disjoint FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_disjoint FROM www;
GRANT ALL ON TABLE chado.feature_disjoint TO www;
GRANT ALL ON TABLE chado.feature_disjoint TO staff;


--
-- Name: TABLE feature_distance; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_distance FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_distance FROM www;
GRANT ALL ON TABLE chado.feature_distance TO www;
GRANT ALL ON TABLE chado.feature_distance TO staff;


--
-- Name: TABLE feature_expression; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_expression FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_expression FROM www;
GRANT ALL ON TABLE chado.feature_expression TO www;
GRANT ALL ON TABLE chado.feature_expression TO staff;


--
-- Name: SEQUENCE feature_expression_feature_expression_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_expression_feature_expression_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_expression_feature_expression_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_expression_feature_expression_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_expression_feature_expression_id_seq TO staff;


--
-- Name: TABLE feature_expressionprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_expressionprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_expressionprop FROM www;
GRANT ALL ON TABLE chado.feature_expressionprop TO www;
GRANT ALL ON TABLE chado.feature_expressionprop TO staff;


--
-- Name: SEQUENCE feature_expressionprop_feature_expressionprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_expressionprop_feature_expressionprop_id_seq TO staff;


--
-- Name: SEQUENCE feature_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_feature_id_seq TO staff;


--
-- Name: TABLE feature_genotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_genotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_genotype FROM www;
GRANT ALL ON TABLE chado.feature_genotype TO www;
GRANT ALL ON TABLE chado.feature_genotype TO staff;


--
-- Name: SEQUENCE feature_genotype_feature_genotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_genotype_feature_genotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_genotype_feature_genotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_genotype_feature_genotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_genotype_feature_genotype_id_seq TO staff;


--
-- Name: TABLE feature_intersection; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_intersection FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_intersection FROM www;
GRANT ALL ON TABLE chado.feature_intersection TO www;
GRANT ALL ON TABLE chado.feature_intersection TO staff;


--
-- Name: TABLE feature_meets; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_meets FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_meets FROM www;
GRANT ALL ON TABLE chado.feature_meets TO www;
GRANT ALL ON TABLE chado.feature_meets TO staff;


--
-- Name: TABLE feature_meets_on_same_strand; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_meets_on_same_strand FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_meets_on_same_strand FROM www;
GRANT ALL ON TABLE chado.feature_meets_on_same_strand TO www;
GRANT ALL ON TABLE chado.feature_meets_on_same_strand TO staff;


--
-- Name: TABLE feature_phenotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_phenotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_phenotype FROM www;
GRANT ALL ON TABLE chado.feature_phenotype TO www;
GRANT ALL ON TABLE chado.feature_phenotype TO staff;


--
-- Name: SEQUENCE feature_phenotype_feature_phenotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_phenotype_feature_phenotype_id_seq TO staff;


--
-- Name: TABLE feature_project; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_project FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_project FROM www;
GRANT ALL ON TABLE chado.feature_project TO www;
GRANT ALL ON TABLE chado.feature_project TO staff;


--
-- Name: SEQUENCE feature_project_feature_project_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_project_feature_project_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_project_feature_project_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_project_feature_project_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_project_feature_project_id_seq TO staff;


--
-- Name: SEQUENCE feature_pub_feature_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_pub_feature_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_pub_feature_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_pub_feature_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_pub_feature_pub_id_seq TO staff;


--
-- Name: TABLE feature_pubprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_pubprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_pubprop FROM www;
GRANT ALL ON TABLE chado.feature_pubprop TO www;
GRANT ALL ON TABLE chado.feature_pubprop TO staff;


--
-- Name: SEQUENCE feature_pubprop_feature_pubprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_pubprop_feature_pubprop_id_seq TO staff;


--
-- Name: TABLE feature_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_relationship FROM www;
GRANT ALL ON TABLE chado.feature_relationship TO www;
GRANT ALL ON TABLE chado.feature_relationship TO staff;


--
-- Name: SEQUENCE feature_relationship_feature_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_relationship_feature_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_relationship_feature_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_relationship_feature_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_relationship_feature_relationship_id_seq TO staff;


--
-- Name: TABLE feature_relationship_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_relationship_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_relationship_pub FROM www;
GRANT ALL ON TABLE chado.feature_relationship_pub TO www;
GRANT ALL ON TABLE chado.feature_relationship_pub TO staff;


--
-- Name: SEQUENCE feature_relationship_pub_feature_relationship_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_relationship_pub_feature_relationship_pub_id_seq TO staff;


--
-- Name: TABLE feature_relationshipprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_relationshipprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_relationshipprop FROM www;
GRANT ALL ON TABLE chado.feature_relationshipprop TO www;
GRANT ALL ON TABLE chado.feature_relationshipprop TO staff;


--
-- Name: SEQUENCE feature_relationshipprop_feature_relationshipprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_relationshipprop_feature_relationshipprop_id_seq TO staff;


--
-- Name: TABLE feature_relationshipprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_relationshipprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_relationshipprop_pub FROM www;
GRANT ALL ON TABLE chado.feature_relationshipprop_pub TO www;
GRANT ALL ON TABLE chado.feature_relationshipprop_pub TO staff;


--
-- Name: SEQUENCE feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq TO staff;


--
-- Name: TABLE feature_stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_stock FROM www;
GRANT ALL ON TABLE chado.feature_stock TO www;
GRANT ALL ON TABLE chado.feature_stock TO staff;


--
-- Name: SEQUENCE feature_stock_feature_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_stock_feature_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_stock_feature_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_stock_feature_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_stock_feature_stock_id_seq TO staff;


--
-- Name: SEQUENCE feature_synonym_feature_synonym_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_synonym_feature_synonym_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_synonym_feature_synonym_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_synonym_feature_synonym_id_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_synonym_feature_synonym_id_seq TO staff;


--
-- Name: TABLE feature_union; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.feature_union FROM PUBLIC;
REVOKE ALL ON TABLE chado.feature_union FROM www;
GRANT ALL ON TABLE chado.feature_union TO www;
GRANT ALL ON TABLE chado.feature_union TO staff;


--
-- Name: SEQUENCE feature_uniquename_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.feature_uniquename_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.feature_uniquename_seq FROM www;
GRANT ALL ON SEQUENCE chado.feature_uniquename_seq TO www;
GRANT ALL ON SEQUENCE chado.feature_uniquename_seq TO staff;


--
-- Name: SEQUENCE featureloc_featureloc_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featureloc_featureloc_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featureloc_featureloc_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featureloc_featureloc_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featureloc_featureloc_id_seq TO staff;


--
-- Name: TABLE featureloc_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureloc_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureloc_pub FROM www;
GRANT ALL ON TABLE chado.featureloc_pub TO www;
GRANT ALL ON TABLE chado.featureloc_pub TO staff;


--
-- Name: SEQUENCE featureloc_pub_featureloc_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featureloc_pub_featureloc_pub_id_seq TO staff;


--
-- Name: TABLE featuremap; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap FROM www;
GRANT ALL ON TABLE chado.featuremap TO www;
GRANT ALL ON TABLE chado.featuremap TO staff;


--
-- Name: TABLE featuremap_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap_contact FROM www;
GRANT ALL ON TABLE chado.featuremap_contact TO www;
GRANT ALL ON TABLE chado.featuremap_contact TO staff;


--
-- Name: SEQUENCE featuremap_contact_featuremap_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_contact_featuremap_contact_id_seq TO staff;


--
-- Name: TABLE featuremap_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap_dbxref FROM www;
GRANT ALL ON TABLE chado.featuremap_dbxref TO www;
GRANT ALL ON TABLE chado.featuremap_dbxref TO staff;


--
-- Name: SEQUENCE featuremap_dbxref_featuremap_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_dbxref_featuremap_dbxref_id_seq TO staff;


--
-- Name: SEQUENCE featuremap_featuremap_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_featuremap_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_featuremap_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_featuremap_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_featuremap_id_seq TO staff;


--
-- Name: TABLE featuremap_organism; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap_organism FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap_organism FROM www;
GRANT ALL ON TABLE chado.featuremap_organism TO www;
GRANT ALL ON TABLE chado.featuremap_organism TO staff;


--
-- Name: SEQUENCE featuremap_organism_featuremap_organism_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_organism_featuremap_organism_id_seq TO staff;


--
-- Name: TABLE featuremap_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap_pub FROM www;
GRANT ALL ON TABLE chado.featuremap_pub TO www;
GRANT ALL ON TABLE chado.featuremap_pub TO staff;


--
-- Name: SEQUENCE featuremap_pub_featuremap_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_pub_featuremap_pub_id_seq TO staff;


--
-- Name: TABLE featuremap_stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremap_stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremap_stock FROM www;
GRANT ALL ON TABLE chado.featuremap_stock TO www;
GRANT ALL ON TABLE chado.featuremap_stock TO staff;


--
-- Name: SEQUENCE featuremap_stock_featuremap_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremap_stock_featuremap_stock_id_seq TO staff;


--
-- Name: TABLE featuremapprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featuremapprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.featuremapprop FROM www;
GRANT ALL ON TABLE chado.featuremapprop TO www;
GRANT ALL ON TABLE chado.featuremapprop TO staff;


--
-- Name: SEQUENCE featuremapprop_featuremapprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featuremapprop_featuremapprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featuremapprop_featuremapprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featuremapprop_featuremapprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featuremapprop_featuremapprop_id_seq TO staff;


--
-- Name: TABLE featurepos; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featurepos FROM PUBLIC;
REVOKE ALL ON TABLE chado.featurepos FROM www;
GRANT ALL ON TABLE chado.featurepos TO www;
GRANT ALL ON TABLE chado.featurepos TO staff;


--
-- Name: SEQUENCE featurepos_featurepos_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featurepos_featurepos_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featurepos_featurepos_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featurepos_featurepos_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featurepos_featurepos_id_seq TO staff;


--
-- Name: TABLE featureposprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureposprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureposprop FROM www;
GRANT ALL ON TABLE chado.featureposprop TO www;
GRANT ALL ON TABLE chado.featureposprop TO staff;


--
-- Name: SEQUENCE featureposprop_featureposprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featureposprop_featureposprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featureposprop_featureposprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featureposprop_featureposprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featureposprop_featureposprop_id_seq TO staff;


--
-- Name: SEQUENCE featureprop_featureprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featureprop_featureprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featureprop_featureprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featureprop_featureprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featureprop_featureprop_id_seq TO staff;


--
-- Name: TABLE featureprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureprop_pub FROM www;
GRANT ALL ON TABLE chado.featureprop_pub TO www;
GRANT ALL ON TABLE chado.featureprop_pub TO staff;


--
-- Name: SEQUENCE featureprop_pub_featureprop_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featureprop_pub_featureprop_pub_id_seq TO staff;


--
-- Name: TABLE featurerange; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featurerange FROM PUBLIC;
REVOKE ALL ON TABLE chado.featurerange FROM www;
GRANT ALL ON TABLE chado.featurerange TO www;
GRANT ALL ON TABLE chado.featurerange TO staff;


--
-- Name: SEQUENCE featurerange_featurerange_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.featurerange_featurerange_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.featurerange_featurerange_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.featurerange_featurerange_id_seq TO www;
GRANT ALL ON SEQUENCE chado.featurerange_featurerange_id_seq TO staff;


--
-- Name: TABLE featureset_meets; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.featureset_meets FROM PUBLIC;
REVOKE ALL ON TABLE chado.featureset_meets FROM www;
GRANT ALL ON TABLE chado.featureset_meets TO www;
GRANT ALL ON TABLE chado.featureset_meets TO staff;


--
-- Name: TABLE fnr_type; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.fnr_type FROM PUBLIC;
REVOKE ALL ON TABLE chado.fnr_type FROM www;
GRANT ALL ON TABLE chado.fnr_type TO www;
GRANT ALL ON TABLE chado.fnr_type TO staff;


--
-- Name: TABLE fp_key; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.fp_key FROM PUBLIC;
REVOKE ALL ON TABLE chado.fp_key FROM www;
GRANT ALL ON TABLE chado.fp_key TO www;
GRANT ALL ON TABLE chado.fp_key TO staff;


--
-- Name: TABLE gene; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.gene FROM PUBLIC;
REVOKE ALL ON TABLE chado.gene FROM www;
GRANT ALL ON TABLE chado.gene TO www;
GRANT ALL ON TABLE chado.gene TO staff;


--
-- Name: TABLE gene2domain; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.gene2domain FROM PUBLIC;
REVOKE ALL ON TABLE chado.gene2domain FROM www;
GRANT ALL ON TABLE chado.gene2domain TO www;
GRANT ALL ON TABLE chado.gene2domain TO staff;


--
-- Name: TABLE genome_metadata; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.genome_metadata FROM PUBLIC;
REVOKE ALL ON TABLE chado.genome_metadata FROM www;
GRANT ALL ON TABLE chado.genome_metadata TO www;
GRANT ALL ON TABLE chado.genome_metadata TO staff;


--
-- Name: TABLE genotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.genotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.genotype FROM www;
GRANT ALL ON TABLE chado.genotype TO www;
GRANT ALL ON TABLE chado.genotype TO staff;


--
-- Name: SEQUENCE genotype_genotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.genotype_genotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.genotype_genotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.genotype_genotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.genotype_genotype_id_seq TO staff;


--
-- Name: TABLE genotypeprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.genotypeprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.genotypeprop FROM www;
GRANT ALL ON TABLE chado.genotypeprop TO www;
GRANT ALL ON TABLE chado.genotypeprop TO staff;


--
-- Name: SEQUENCE genotypeprop_genotypeprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.genotypeprop_genotypeprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.genotypeprop_genotypeprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.genotypeprop_genotypeprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.genotypeprop_genotypeprop_id_seq TO staff;


--
-- Name: TABLE gff3atts; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.gff3atts FROM PUBLIC;
REVOKE ALL ON TABLE chado.gff3atts FROM www;
GRANT ALL ON TABLE chado.gff3atts TO www;
GRANT ALL ON TABLE chado.gff3atts TO staff;


--
-- Name: TABLE gff3view; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.gff3view FROM PUBLIC;
REVOKE ALL ON TABLE chado.gff3view FROM www;
GRANT ALL ON TABLE chado.gff3view TO www;
GRANT ALL ON TABLE chado.gff3view TO staff;


--
-- Name: TABLE intron_combined_view; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.intron_combined_view FROM PUBLIC;
REVOKE ALL ON TABLE chado.intron_combined_view FROM www;
GRANT ALL ON TABLE chado.intron_combined_view TO www;
GRANT ALL ON TABLE chado.intron_combined_view TO staff;


--
-- Name: TABLE intronloc_view; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.intronloc_view FROM PUBLIC;
REVOKE ALL ON TABLE chado.intronloc_view FROM www;
GRANT ALL ON TABLE chado.intronloc_view TO www;
GRANT ALL ON TABLE chado.intronloc_view TO staff;


--
-- Name: TABLE library; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library FROM PUBLIC;
REVOKE ALL ON TABLE chado.library FROM www;
GRANT ALL ON TABLE chado.library TO www;
GRANT ALL ON TABLE chado.library TO staff;


--
-- Name: TABLE library_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_contact FROM www;
GRANT ALL ON TABLE chado.library_contact TO www;
GRANT ALL ON TABLE chado.library_contact TO staff;


--
-- Name: SEQUENCE library_contact_library_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_contact_library_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_contact_library_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_contact_library_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_contact_library_contact_id_seq TO staff;


--
-- Name: TABLE library_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_cvterm FROM www;
GRANT ALL ON TABLE chado.library_cvterm TO www;
GRANT ALL ON TABLE chado.library_cvterm TO staff;


--
-- Name: SEQUENCE library_cvterm_library_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_cvterm_library_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_cvterm_library_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_cvterm_library_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_cvterm_library_cvterm_id_seq TO staff;


--
-- Name: TABLE library_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_dbxref FROM www;
GRANT ALL ON TABLE chado.library_dbxref TO www;
GRANT ALL ON TABLE chado.library_dbxref TO staff;


--
-- Name: SEQUENCE library_dbxref_library_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_dbxref_library_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_dbxref_library_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_dbxref_library_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_dbxref_library_dbxref_id_seq TO staff;


--
-- Name: TABLE library_expression; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_expression FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_expression FROM www;
GRANT ALL ON TABLE chado.library_expression TO www;
GRANT ALL ON TABLE chado.library_expression TO staff;


--
-- Name: SEQUENCE library_expression_library_expression_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_expression_library_expression_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_expression_library_expression_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_expression_library_expression_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_expression_library_expression_id_seq TO staff;


--
-- Name: TABLE library_expressionprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_expressionprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_expressionprop FROM www;
GRANT ALL ON TABLE chado.library_expressionprop TO www;
GRANT ALL ON TABLE chado.library_expressionprop TO staff;


--
-- Name: SEQUENCE library_expressionprop_library_expressionprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_expressionprop_library_expressionprop_id_seq TO staff;


--
-- Name: TABLE library_feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_feature FROM www;
GRANT ALL ON TABLE chado.library_feature TO www;
GRANT ALL ON TABLE chado.library_feature TO staff;


--
-- Name: TABLE library_feature_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_feature_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_feature_count FROM www;
GRANT ALL ON TABLE chado.library_feature_count TO www;
GRANT ALL ON TABLE chado.library_feature_count TO staff;


--
-- Name: SEQUENCE library_feature_library_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_feature_library_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_feature_library_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_feature_library_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_feature_library_feature_id_seq TO staff;


--
-- Name: TABLE library_featureprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_featureprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_featureprop FROM www;
GRANT ALL ON TABLE chado.library_featureprop TO www;
GRANT ALL ON TABLE chado.library_featureprop TO staff;


--
-- Name: SEQUENCE library_featureprop_library_featureprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_featureprop_library_featureprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_featureprop_library_featureprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_featureprop_library_featureprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_featureprop_library_featureprop_id_seq TO staff;


--
-- Name: SEQUENCE library_library_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_library_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_library_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_library_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_library_id_seq TO staff;


--
-- Name: TABLE library_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_pub FROM www;
GRANT ALL ON TABLE chado.library_pub TO www;
GRANT ALL ON TABLE chado.library_pub TO staff;


--
-- Name: SEQUENCE library_pub_library_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_pub_library_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_pub_library_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_pub_library_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_pub_library_pub_id_seq TO staff;


--
-- Name: TABLE library_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_relationship FROM www;
GRANT ALL ON TABLE chado.library_relationship TO www;
GRANT ALL ON TABLE chado.library_relationship TO staff;


--
-- Name: SEQUENCE library_relationship_library_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_relationship_library_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_relationship_library_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_relationship_library_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_relationship_library_relationship_id_seq TO staff;


--
-- Name: TABLE library_relationship_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_relationship_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_relationship_pub FROM www;
GRANT ALL ON TABLE chado.library_relationship_pub TO www;
GRANT ALL ON TABLE chado.library_relationship_pub TO staff;


--
-- Name: SEQUENCE library_relationship_pub_library_relationship_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_relationship_pub_library_relationship_pub_id_seq TO staff;


--
-- Name: TABLE library_synonym; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.library_synonym FROM PUBLIC;
REVOKE ALL ON TABLE chado.library_synonym FROM www;
GRANT ALL ON TABLE chado.library_synonym TO www;
GRANT ALL ON TABLE chado.library_synonym TO staff;


--
-- Name: SEQUENCE library_synonym_library_synonym_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.library_synonym_library_synonym_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.library_synonym_library_synonym_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.library_synonym_library_synonym_id_seq TO www;
GRANT ALL ON SEQUENCE chado.library_synonym_library_synonym_id_seq TO staff;


--
-- Name: TABLE libraryprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.libraryprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.libraryprop FROM www;
GRANT ALL ON TABLE chado.libraryprop TO www;
GRANT ALL ON TABLE chado.libraryprop TO staff;


--
-- Name: SEQUENCE libraryprop_libraryprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.libraryprop_libraryprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.libraryprop_libraryprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.libraryprop_libraryprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.libraryprop_libraryprop_id_seq TO staff;


--
-- Name: TABLE libraryprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.libraryprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.libraryprop_pub FROM www;
GRANT ALL ON TABLE chado.libraryprop_pub TO www;
GRANT ALL ON TABLE chado.libraryprop_pub TO staff;


--
-- Name: SEQUENCE libraryprop_pub_libraryprop_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.libraryprop_pub_libraryprop_pub_id_seq TO staff;


--
-- Name: TABLE magedocumentation; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.magedocumentation FROM PUBLIC;
REVOKE ALL ON TABLE chado.magedocumentation FROM www;
GRANT ALL ON TABLE chado.magedocumentation TO www;
GRANT ALL ON TABLE chado.magedocumentation TO staff;


--
-- Name: SEQUENCE magedocumentation_magedocumentation_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.magedocumentation_magedocumentation_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.magedocumentation_magedocumentation_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.magedocumentation_magedocumentation_id_seq TO www;
GRANT ALL ON SEQUENCE chado.magedocumentation_magedocumentation_id_seq TO staff;


--
-- Name: TABLE mageml; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.mageml FROM PUBLIC;
REVOKE ALL ON TABLE chado.mageml FROM www;
GRANT ALL ON TABLE chado.mageml TO www;
GRANT ALL ON TABLE chado.mageml TO staff;


--
-- Name: SEQUENCE mageml_mageml_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.mageml_mageml_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.mageml_mageml_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.mageml_mageml_id_seq TO www;
GRANT ALL ON SEQUENCE chado.mageml_mageml_id_seq TO staff;


--
-- Name: TABLE marker_search; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.marker_search FROM PUBLIC;
REVOKE ALL ON TABLE chado.marker_search FROM www;
GRANT ALL ON TABLE chado.marker_search TO www;
GRANT ALL ON TABLE chado.marker_search TO staff;


--
-- Name: TABLE materialized_view; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.materialized_view FROM PUBLIC;
REVOKE ALL ON TABLE chado.materialized_view FROM www;
GRANT ALL ON TABLE chado.materialized_view TO www;
GRANT ALL ON TABLE chado.materialized_view TO staff;


--
-- Name: SEQUENCE materialized_view_materialized_view_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.materialized_view_materialized_view_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.materialized_view_materialized_view_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.materialized_view_materialized_view_id_seq TO www;
GRANT ALL ON SEQUENCE chado.materialized_view_materialized_view_id_seq TO staff;


--
-- Name: TABLE nd_experiment; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment FROM www;
GRANT ALL ON TABLE chado.nd_experiment TO www;
GRANT ALL ON TABLE chado.nd_experiment TO staff;


--
-- Name: TABLE nd_experiment_analysis; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_analysis FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_analysis FROM www;
GRANT ALL ON TABLE chado.nd_experiment_analysis TO www;
GRANT ALL ON TABLE chado.nd_experiment_analysis TO staff;


--
-- Name: SEQUENCE nd_experiment_analysis_nd_experiment_analysis_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_analysis_nd_experiment_analysis_id_seq TO staff;


--
-- Name: TABLE nd_experiment_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_contact FROM www;
GRANT ALL ON TABLE chado.nd_experiment_contact TO www;
GRANT ALL ON TABLE chado.nd_experiment_contact TO staff;


--
-- Name: SEQUENCE nd_experiment_contact_nd_experiment_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_contact_nd_experiment_contact_id_seq TO staff;


--
-- Name: TABLE nd_experiment_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_dbxref FROM www;
GRANT ALL ON TABLE chado.nd_experiment_dbxref TO www;
GRANT ALL ON TABLE chado.nd_experiment_dbxref TO staff;


--
-- Name: SEQUENCE nd_experiment_dbxref_nd_experiment_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_dbxref_nd_experiment_dbxref_id_seq TO staff;


--
-- Name: TABLE nd_experiment_genotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_genotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_genotype FROM www;
GRANT ALL ON TABLE chado.nd_experiment_genotype TO www;
GRANT ALL ON TABLE chado.nd_experiment_genotype TO staff;


--
-- Name: SEQUENCE nd_experiment_genotype_nd_experiment_genotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_genotype_nd_experiment_genotype_id_seq TO staff;


--
-- Name: SEQUENCE nd_experiment_nd_experiment_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_nd_experiment_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_nd_experiment_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_nd_experiment_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_nd_experiment_id_seq TO staff;


--
-- Name: TABLE nd_experiment_phenotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_phenotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_phenotype FROM www;
GRANT ALL ON TABLE chado.nd_experiment_phenotype TO www;
GRANT ALL ON TABLE chado.nd_experiment_phenotype TO staff;


--
-- Name: SEQUENCE nd_experiment_phenotype_nd_experiment_phenotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_phenotype_nd_experiment_phenotype_id_seq TO staff;


--
-- Name: TABLE nd_experiment_project; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_project FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_project FROM www;
GRANT ALL ON TABLE chado.nd_experiment_project TO www;
GRANT ALL ON TABLE chado.nd_experiment_project TO staff;


--
-- Name: SEQUENCE nd_experiment_project_nd_experiment_project_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_project_nd_experiment_project_id_seq TO staff;


--
-- Name: TABLE nd_experiment_protocol; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_protocol FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_protocol FROM www;
GRANT ALL ON TABLE chado.nd_experiment_protocol TO www;
GRANT ALL ON TABLE chado.nd_experiment_protocol TO staff;


--
-- Name: SEQUENCE nd_experiment_protocol_nd_experiment_protocol_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_protocol_nd_experiment_protocol_id_seq TO staff;


--
-- Name: TABLE nd_experiment_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_pub FROM www;
GRANT ALL ON TABLE chado.nd_experiment_pub TO www;
GRANT ALL ON TABLE chado.nd_experiment_pub TO staff;


--
-- Name: SEQUENCE nd_experiment_pub_nd_experiment_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_pub_nd_experiment_pub_id_seq TO staff;


--
-- Name: TABLE nd_experiment_stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_stock FROM www;
GRANT ALL ON TABLE chado.nd_experiment_stock TO www;
GRANT ALL ON TABLE chado.nd_experiment_stock TO staff;


--
-- Name: TABLE nd_experiment_stock_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_stock_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_stock_dbxref FROM www;
GRANT ALL ON TABLE chado.nd_experiment_stock_dbxref TO www;
GRANT ALL ON TABLE chado.nd_experiment_stock_dbxref TO staff;


--
-- Name: SEQUENCE nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stock_dbxref_nd_experiment_stock_dbxref_id_seq TO staff;


--
-- Name: SEQUENCE nd_experiment_stock_nd_experiment_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stock_nd_experiment_stock_id_seq TO staff;


--
-- Name: TABLE nd_experiment_stockprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experiment_stockprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experiment_stockprop FROM www;
GRANT ALL ON TABLE chado.nd_experiment_stockprop TO www;
GRANT ALL ON TABLE chado.nd_experiment_stockprop TO staff;


--
-- Name: SEQUENCE nd_experiment_stockprop_nd_experiment_stockprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experiment_stockprop_nd_experiment_stockprop_id_seq TO staff;


--
-- Name: TABLE nd_experimentprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_experimentprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_experimentprop FROM www;
GRANT ALL ON TABLE chado.nd_experimentprop TO www;
GRANT ALL ON TABLE chado.nd_experimentprop TO staff;


--
-- Name: SEQUENCE nd_experimentprop_nd_experimentprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_experimentprop_nd_experimentprop_id_seq TO staff;


--
-- Name: TABLE nd_geolocation; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_geolocation FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_geolocation FROM www;
GRANT ALL ON TABLE chado.nd_geolocation TO www;
GRANT ALL ON TABLE chado.nd_geolocation TO staff;


--
-- Name: SEQUENCE nd_geolocation_nd_geolocation_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_geolocation_nd_geolocation_id_seq TO staff;


--
-- Name: TABLE nd_geolocationprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_geolocationprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_geolocationprop FROM www;
GRANT ALL ON TABLE chado.nd_geolocationprop TO www;
GRANT ALL ON TABLE chado.nd_geolocationprop TO staff;


--
-- Name: SEQUENCE nd_geolocationprop_nd_geolocationprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_geolocationprop_nd_geolocationprop_id_seq TO staff;


--
-- Name: TABLE nd_protocol; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_protocol FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_protocol FROM www;
GRANT ALL ON TABLE chado.nd_protocol TO www;
GRANT ALL ON TABLE chado.nd_protocol TO staff;


--
-- Name: SEQUENCE nd_protocol_nd_protocol_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_protocol_nd_protocol_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_protocol_nd_protocol_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_protocol_nd_protocol_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_protocol_nd_protocol_id_seq TO staff;


--
-- Name: TABLE nd_protocol_reagent; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_protocol_reagent FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_protocol_reagent FROM www;
GRANT ALL ON TABLE chado.nd_protocol_reagent TO www;
GRANT ALL ON TABLE chado.nd_protocol_reagent TO staff;


--
-- Name: SEQUENCE nd_protocol_reagent_nd_protocol_reagent_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_protocol_reagent_nd_protocol_reagent_id_seq TO staff;


--
-- Name: TABLE nd_protocolprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_protocolprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_protocolprop FROM www;
GRANT ALL ON TABLE chado.nd_protocolprop TO www;
GRANT ALL ON TABLE chado.nd_protocolprop TO staff;


--
-- Name: SEQUENCE nd_protocolprop_nd_protocolprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_protocolprop_nd_protocolprop_id_seq TO staff;


--
-- Name: TABLE nd_reagent; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_reagent FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_reagent FROM www;
GRANT ALL ON TABLE chado.nd_reagent TO www;
GRANT ALL ON TABLE chado.nd_reagent TO staff;


--
-- Name: SEQUENCE nd_reagent_nd_reagent_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_reagent_nd_reagent_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_reagent_nd_reagent_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_reagent_nd_reagent_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_reagent_nd_reagent_id_seq TO staff;


--
-- Name: TABLE nd_reagent_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_reagent_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_reagent_relationship FROM www;
GRANT ALL ON TABLE chado.nd_reagent_relationship TO www;
GRANT ALL ON TABLE chado.nd_reagent_relationship TO staff;


--
-- Name: SEQUENCE nd_reagent_relationship_nd_reagent_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_reagent_relationship_nd_reagent_relationship_id_seq TO staff;


--
-- Name: TABLE nd_reagentprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.nd_reagentprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.nd_reagentprop FROM www;
GRANT ALL ON TABLE chado.nd_reagentprop TO www;
GRANT ALL ON TABLE chado.nd_reagentprop TO staff;


--
-- Name: SEQUENCE nd_reagentprop_nd_reagentprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.nd_reagentprop_nd_reagentprop_id_seq TO staff;


--
-- Name: TABLE organism; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism FROM www;
GRANT ALL ON TABLE chado.organism TO www;
GRANT ALL ON TABLE chado.organism TO staff;


--
-- Name: TABLE organism_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_cvterm FROM www;
GRANT ALL ON TABLE chado.organism_cvterm TO www;
GRANT ALL ON TABLE chado.organism_cvterm TO staff;


--
-- Name: SEQUENCE organism_cvterm_organism_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_cvterm_organism_cvterm_id_seq TO staff;


--
-- Name: TABLE organism_cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_cvtermprop FROM www;
GRANT ALL ON TABLE chado.organism_cvtermprop TO www;
GRANT ALL ON TABLE chado.organism_cvtermprop TO staff;


--
-- Name: SEQUENCE organism_cvtermprop_organism_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_cvtermprop_organism_cvtermprop_id_seq TO staff;


--
-- Name: TABLE organism_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_dbxref FROM www;
GRANT ALL ON TABLE chado.organism_dbxref TO www;
GRANT ALL ON TABLE chado.organism_dbxref TO staff;


--
-- Name: SEQUENCE organism_dbxref_organism_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_dbxref_organism_dbxref_id_seq TO staff;


--
-- Name: TABLE organism_feature_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_feature_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_feature_count FROM www;
GRANT ALL ON TABLE chado.organism_feature_count TO www;
GRANT ALL ON TABLE chado.organism_feature_count TO staff;


--
-- Name: SEQUENCE organism_organism_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_organism_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_organism_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_organism_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_organism_id_seq TO staff;


--
-- Name: TABLE organism_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_pub FROM www;
GRANT ALL ON TABLE chado.organism_pub TO www;
GRANT ALL ON TABLE chado.organism_pub TO staff;


--
-- Name: SEQUENCE organism_pub_organism_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_pub_organism_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_pub_organism_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_pub_organism_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_pub_organism_pub_id_seq TO staff;


--
-- Name: TABLE organism_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organism_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.organism_relationship FROM www;
GRANT ALL ON TABLE chado.organism_relationship TO www;
GRANT ALL ON TABLE chado.organism_relationship TO staff;


--
-- Name: SEQUENCE organism_relationship_organism_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organism_relationship_organism_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organism_relationship_organism_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organism_relationship_organism_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organism_relationship_organism_relationship_id_seq TO staff;


--
-- Name: TABLE organismprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organismprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.organismprop FROM www;
GRANT ALL ON TABLE chado.organismprop TO www;
GRANT ALL ON TABLE chado.organismprop TO staff;


--
-- Name: SEQUENCE organismprop_organismprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organismprop_organismprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organismprop_organismprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organismprop_organismprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organismprop_organismprop_id_seq TO staff;


--
-- Name: TABLE organismprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.organismprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.organismprop_pub FROM www;
GRANT ALL ON TABLE chado.organismprop_pub TO www;
GRANT ALL ON TABLE chado.organismprop_pub TO staff;


--
-- Name: SEQUENCE organismprop_pub_organismprop_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.organismprop_pub_organismprop_pub_id_seq TO staff;


--
-- Name: TABLE phendesc; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phendesc FROM PUBLIC;
REVOKE ALL ON TABLE chado.phendesc FROM www;
GRANT ALL ON TABLE chado.phendesc TO www;
GRANT ALL ON TABLE chado.phendesc TO staff;


--
-- Name: SEQUENCE phendesc_phendesc_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phendesc_phendesc_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phendesc_phendesc_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phendesc_phendesc_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phendesc_phendesc_id_seq TO staff;


--
-- Name: TABLE phenotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenotype FROM www;
GRANT ALL ON TABLE chado.phenotype TO www;
GRANT ALL ON TABLE chado.phenotype TO staff;


--
-- Name: TABLE phenotype_comparison; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenotype_comparison FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenotype_comparison FROM www;
GRANT ALL ON TABLE chado.phenotype_comparison TO www;
GRANT ALL ON TABLE chado.phenotype_comparison TO staff;


--
-- Name: TABLE phenotype_comparison_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenotype_comparison_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenotype_comparison_cvterm FROM www;
GRANT ALL ON TABLE chado.phenotype_comparison_cvterm TO www;
GRANT ALL ON TABLE chado.phenotype_comparison_cvterm TO staff;


--
-- Name: SEQUENCE phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenotype_comparison_cvterm_phenotype_comparison_cvterm_id_seq TO staff;


--
-- Name: SEQUENCE phenotype_comparison_phenotype_comparison_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenotype_comparison_phenotype_comparison_id_seq TO staff;


--
-- Name: TABLE phenotype_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenotype_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenotype_cvterm FROM www;
GRANT ALL ON TABLE chado.phenotype_cvterm TO www;
GRANT ALL ON TABLE chado.phenotype_cvterm TO staff;


--
-- Name: SEQUENCE phenotype_cvterm_phenotype_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenotype_cvterm_phenotype_cvterm_id_seq TO staff;


--
-- Name: SEQUENCE phenotype_phenotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenotype_phenotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenotype_phenotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenotype_phenotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenotype_phenotype_id_seq TO staff;


--
-- Name: TABLE phenotypeprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenotypeprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenotypeprop FROM www;
GRANT ALL ON TABLE chado.phenotypeprop TO www;
GRANT ALL ON TABLE chado.phenotypeprop TO staff;


--
-- Name: SEQUENCE phenotypeprop_phenotypeprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenotypeprop_phenotypeprop_id_seq TO staff;


--
-- Name: TABLE phenstatement; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phenstatement FROM PUBLIC;
REVOKE ALL ON TABLE chado.phenstatement FROM www;
GRANT ALL ON TABLE chado.phenstatement TO www;
GRANT ALL ON TABLE chado.phenstatement TO staff;


--
-- Name: SEQUENCE phenstatement_phenstatement_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phenstatement_phenstatement_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phenstatement_phenstatement_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phenstatement_phenstatement_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phenstatement_phenstatement_id_seq TO staff;


--
-- Name: TABLE phylonode; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonode FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonode FROM www;
GRANT ALL ON TABLE chado.phylonode TO www;
GRANT ALL ON TABLE chado.phylonode TO staff;


--
-- Name: TABLE phylonode_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonode_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonode_dbxref FROM www;
GRANT ALL ON TABLE chado.phylonode_dbxref TO www;
GRANT ALL ON TABLE chado.phylonode_dbxref TO staff;


--
-- Name: SEQUENCE phylonode_dbxref_phylonode_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonode_dbxref_phylonode_dbxref_id_seq TO staff;


--
-- Name: TABLE phylonode_organism; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonode_organism FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonode_organism FROM www;
GRANT ALL ON TABLE chado.phylonode_organism TO www;
GRANT ALL ON TABLE chado.phylonode_organism TO staff;


--
-- Name: SEQUENCE phylonode_organism_phylonode_organism_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonode_organism_phylonode_organism_id_seq TO staff;


--
-- Name: SEQUENCE phylonode_phylonode_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonode_phylonode_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonode_phylonode_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonode_phylonode_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonode_phylonode_id_seq TO staff;


--
-- Name: TABLE phylonode_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonode_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonode_pub FROM www;
GRANT ALL ON TABLE chado.phylonode_pub TO www;
GRANT ALL ON TABLE chado.phylonode_pub TO staff;


--
-- Name: SEQUENCE phylonode_pub_phylonode_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonode_pub_phylonode_pub_id_seq TO staff;


--
-- Name: TABLE phylonode_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonode_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonode_relationship FROM www;
GRANT ALL ON TABLE chado.phylonode_relationship TO www;
GRANT ALL ON TABLE chado.phylonode_relationship TO staff;


--
-- Name: SEQUENCE phylonode_relationship_phylonode_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonode_relationship_phylonode_relationship_id_seq TO staff;


--
-- Name: TABLE phylonodeprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylonodeprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylonodeprop FROM www;
GRANT ALL ON TABLE chado.phylonodeprop TO www;
GRANT ALL ON TABLE chado.phylonodeprop TO staff;


--
-- Name: SEQUENCE phylonodeprop_phylonodeprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylonodeprop_phylonodeprop_id_seq TO staff;


--
-- Name: TABLE phylotree; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylotree FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylotree FROM www;
GRANT ALL ON TABLE chado.phylotree TO www;
GRANT ALL ON TABLE chado.phylotree TO staff;


--
-- Name: SEQUENCE phylotree_phylotree_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylotree_phylotree_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylotree_phylotree_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylotree_phylotree_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylotree_phylotree_id_seq TO staff;


--
-- Name: TABLE phylotree_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylotree_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylotree_pub FROM www;
GRANT ALL ON TABLE chado.phylotree_pub TO www;
GRANT ALL ON TABLE chado.phylotree_pub TO staff;


--
-- Name: SEQUENCE phylotree_pub_phylotree_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylotree_pub_phylotree_pub_id_seq TO staff;


--
-- Name: TABLE phylotreeprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.phylotreeprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.phylotreeprop FROM www;
GRANT ALL ON TABLE chado.phylotreeprop TO www;
GRANT ALL ON TABLE chado.phylotreeprop TO staff;


--
-- Name: SEQUENCE phylotreeprop_phylotreeprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.phylotreeprop_phylotreeprop_id_seq TO staff;


--
-- Name: TABLE project; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project FROM PUBLIC;
REVOKE ALL ON TABLE chado.project FROM www;
GRANT ALL ON TABLE chado.project TO www;
GRANT ALL ON TABLE chado.project TO staff;


--
-- Name: TABLE project_analysis; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_analysis FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_analysis FROM www;
GRANT ALL ON TABLE chado.project_analysis TO www;
GRANT ALL ON TABLE chado.project_analysis TO staff;


--
-- Name: SEQUENCE project_analysis_project_analysis_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_analysis_project_analysis_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_analysis_project_analysis_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_analysis_project_analysis_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_analysis_project_analysis_id_seq TO staff;


--
-- Name: TABLE project_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_contact FROM www;
GRANT ALL ON TABLE chado.project_contact TO www;
GRANT ALL ON TABLE chado.project_contact TO staff;


--
-- Name: SEQUENCE project_contact_project_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_contact_project_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_contact_project_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_contact_project_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_contact_project_contact_id_seq TO staff;


--
-- Name: TABLE project_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_dbxref FROM www;
GRANT ALL ON TABLE chado.project_dbxref TO www;
GRANT ALL ON TABLE chado.project_dbxref TO staff;


--
-- Name: SEQUENCE project_dbxref_project_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_dbxref_project_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_dbxref_project_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_dbxref_project_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_dbxref_project_dbxref_id_seq TO staff;


--
-- Name: TABLE project_feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_feature FROM www;
GRANT ALL ON TABLE chado.project_feature TO www;
GRANT ALL ON TABLE chado.project_feature TO staff;


--
-- Name: SEQUENCE project_feature_project_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_feature_project_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_feature_project_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_feature_project_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_feature_project_feature_id_seq TO staff;


--
-- Name: TABLE project_phenotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_phenotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_phenotype FROM www;
GRANT ALL ON TABLE chado.project_phenotype TO www;
GRANT ALL ON TABLE chado.project_phenotype TO staff;


--
-- Name: SEQUENCE project_phenotype_project_phenotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_phenotype_project_phenotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_phenotype_project_phenotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_phenotype_project_phenotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_phenotype_project_phenotype_id_seq TO staff;


--
-- Name: SEQUENCE project_project_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_project_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_project_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_project_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_project_id_seq TO staff;


--
-- Name: TABLE project_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_pub FROM www;
GRANT ALL ON TABLE chado.project_pub TO www;
GRANT ALL ON TABLE chado.project_pub TO staff;


--
-- Name: SEQUENCE project_pub_project_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_pub_project_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_pub_project_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_pub_project_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_pub_project_pub_id_seq TO staff;


--
-- Name: TABLE project_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_relationship FROM www;
GRANT ALL ON TABLE chado.project_relationship TO www;
GRANT ALL ON TABLE chado.project_relationship TO staff;


--
-- Name: SEQUENCE project_relationship_project_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_relationship_project_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_relationship_project_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_relationship_project_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_relationship_project_relationship_id_seq TO staff;


--
-- Name: SEQUENCE project_stock_project_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.project_stock_project_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.project_stock_project_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.project_stock_project_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.project_stock_project_stock_id_seq TO staff;


--
-- Name: TABLE project_stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.project_stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.project_stock FROM www;
GRANT ALL ON TABLE chado.project_stock TO www;
GRANT ALL ON TABLE chado.project_stock TO staff;


--
-- Name: TABLE projectprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.projectprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.projectprop FROM www;
GRANT ALL ON TABLE chado.projectprop TO www;
GRANT ALL ON TABLE chado.projectprop TO staff;


--
-- Name: SEQUENCE projectprop_projectprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.projectprop_projectprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.projectprop_projectprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.projectprop_projectprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.projectprop_projectprop_id_seq TO staff;


--
-- Name: TABLE protocol; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.protocol FROM PUBLIC;
REVOKE ALL ON TABLE chado.protocol FROM www;
GRANT ALL ON TABLE chado.protocol TO www;
GRANT ALL ON TABLE chado.protocol TO staff;


--
-- Name: SEQUENCE protocol_protocol_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.protocol_protocol_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.protocol_protocol_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.protocol_protocol_id_seq TO www;
GRANT ALL ON SEQUENCE chado.protocol_protocol_id_seq TO staff;


--
-- Name: TABLE protocolparam; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.protocolparam FROM PUBLIC;
REVOKE ALL ON TABLE chado.protocolparam FROM www;
GRANT ALL ON TABLE chado.protocolparam TO www;
GRANT ALL ON TABLE chado.protocolparam TO staff;


--
-- Name: SEQUENCE protocolparam_protocolparam_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.protocolparam_protocolparam_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.protocolparam_protocolparam_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.protocolparam_protocolparam_id_seq TO www;
GRANT ALL ON SEQUENCE chado.protocolparam_protocolparam_id_seq TO staff;


--
-- Name: TABLE pub_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pub_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.pub_dbxref FROM www;
GRANT ALL ON TABLE chado.pub_dbxref TO www;
GRANT ALL ON TABLE chado.pub_dbxref TO staff;


--
-- Name: SEQUENCE pub_dbxref_pub_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pub_dbxref_pub_dbxref_id_seq TO staff;


--
-- Name: SEQUENCE pub_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pub_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pub_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pub_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pub_pub_id_seq TO staff;


--
-- Name: TABLE pub_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pub_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.pub_relationship FROM www;
GRANT ALL ON TABLE chado.pub_relationship TO www;
GRANT ALL ON TABLE chado.pub_relationship TO staff;


--
-- Name: SEQUENCE pub_relationship_pub_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pub_relationship_pub_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pub_relationship_pub_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pub_relationship_pub_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pub_relationship_pub_relationship_id_seq TO staff;


--
-- Name: TABLE pubauthor; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pubauthor FROM PUBLIC;
REVOKE ALL ON TABLE chado.pubauthor FROM www;
GRANT ALL ON TABLE chado.pubauthor TO www;
GRANT ALL ON TABLE chado.pubauthor TO staff;


--
-- Name: TABLE pubauthor_contact; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pubauthor_contact FROM PUBLIC;
REVOKE ALL ON TABLE chado.pubauthor_contact FROM www;
GRANT ALL ON TABLE chado.pubauthor_contact TO www;
GRANT ALL ON TABLE chado.pubauthor_contact TO staff;


--
-- Name: SEQUENCE pubauthor_contact_pubauthor_contact_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pubauthor_contact_pubauthor_contact_id_seq TO staff;


--
-- Name: SEQUENCE pubauthor_pubauthor_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pubauthor_pubauthor_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pubauthor_pubauthor_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pubauthor_pubauthor_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pubauthor_pubauthor_id_seq TO staff;


--
-- Name: TABLE pubprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.pubprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.pubprop FROM www;
GRANT ALL ON TABLE chado.pubprop TO www;
GRANT ALL ON TABLE chado.pubprop TO staff;


--
-- Name: SEQUENCE pubprop_pubprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.pubprop_pubprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.pubprop_pubprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.pubprop_pubprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.pubprop_pubprop_id_seq TO staff;


--
-- Name: TABLE qtl_map_position; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.qtl_map_position FROM PUBLIC;
REVOKE ALL ON TABLE chado.qtl_map_position FROM www;
GRANT ALL ON TABLE chado.qtl_map_position TO www;
GRANT ALL ON TABLE chado.qtl_map_position TO staff;


--
-- Name: TABLE qtl_search; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.qtl_search FROM PUBLIC;
REVOKE ALL ON TABLE chado.qtl_search FROM www;
GRANT ALL ON TABLE chado.qtl_search TO www;
GRANT ALL ON TABLE chado.qtl_search TO staff;


--
-- Name: TABLE quantification; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.quantification FROM PUBLIC;
REVOKE ALL ON TABLE chado.quantification FROM www;
GRANT ALL ON TABLE chado.quantification TO www;
GRANT ALL ON TABLE chado.quantification TO staff;


--
-- Name: SEQUENCE quantification_quantification_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.quantification_quantification_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.quantification_quantification_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.quantification_quantification_id_seq TO www;
GRANT ALL ON SEQUENCE chado.quantification_quantification_id_seq TO staff;


--
-- Name: TABLE quantification_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.quantification_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.quantification_relationship FROM www;
GRANT ALL ON TABLE chado.quantification_relationship TO www;
GRANT ALL ON TABLE chado.quantification_relationship TO staff;


--
-- Name: SEQUENCE quantification_relationship_quantification_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.quantification_relationship_quantification_relationship_id_seq TO staff;


--
-- Name: TABLE quantificationprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.quantificationprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.quantificationprop FROM www;
GRANT ALL ON TABLE chado.quantificationprop TO www;
GRANT ALL ON TABLE chado.quantificationprop TO staff;


--
-- Name: SEQUENCE quantificationprop_quantificationprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.quantificationprop_quantificationprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.quantificationprop_quantificationprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.quantificationprop_quantificationprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.quantificationprop_quantificationprop_id_seq TO staff;


--
-- Name: TABLE stats_paths_to_root; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stats_paths_to_root FROM PUBLIC;
REVOKE ALL ON TABLE chado.stats_paths_to_root FROM www;
GRANT ALL ON TABLE chado.stats_paths_to_root TO www;
GRANT ALL ON TABLE chado.stats_paths_to_root TO staff;


--
-- Name: TABLE stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock FROM www;
GRANT ALL ON TABLE chado.stock TO www;
GRANT ALL ON TABLE chado.stock TO staff;


--
-- Name: TABLE stock_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_cvterm FROM www;
GRANT ALL ON TABLE chado.stock_cvterm TO www;
GRANT ALL ON TABLE chado.stock_cvterm TO staff;


--
-- Name: SEQUENCE stock_cvterm_stock_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_cvterm_stock_cvterm_id_seq TO staff;


--
-- Name: TABLE stock_cvtermprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_cvtermprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_cvtermprop FROM www;
GRANT ALL ON TABLE chado.stock_cvtermprop TO www;
GRANT ALL ON TABLE chado.stock_cvtermprop TO staff;


--
-- Name: SEQUENCE stock_cvtermprop_stock_cvtermprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_cvtermprop_stock_cvtermprop_id_seq TO staff;


--
-- Name: TABLE stock_dbxref; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_dbxref FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_dbxref FROM www;
GRANT ALL ON TABLE chado.stock_dbxref TO www;
GRANT ALL ON TABLE chado.stock_dbxref TO staff;


--
-- Name: SEQUENCE stock_dbxref_stock_dbxref_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_dbxref_stock_dbxref_id_seq TO staff;


--
-- Name: TABLE stock_dbxrefprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_dbxrefprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_dbxrefprop FROM www;
GRANT ALL ON TABLE chado.stock_dbxrefprop TO www;
GRANT ALL ON TABLE chado.stock_dbxrefprop TO staff;


--
-- Name: SEQUENCE stock_dbxrefprop_stock_dbxrefprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_dbxrefprop_stock_dbxrefprop_id_seq TO staff;


--
-- Name: TABLE stock_eimage; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_eimage FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_eimage FROM www;
GRANT ALL ON TABLE chado.stock_eimage TO www;
GRANT ALL ON TABLE chado.stock_eimage TO staff;


--
-- Name: SEQUENCE stock_eimage_stock_eimage_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_eimage_stock_eimage_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_eimage_stock_eimage_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_eimage_stock_eimage_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_eimage_stock_eimage_id_seq TO staff;


--
-- Name: TABLE stock_feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_feature FROM www;
GRANT ALL ON TABLE chado.stock_feature TO www;
GRANT ALL ON TABLE chado.stock_feature TO staff;


--
-- Name: SEQUENCE stock_feature_stock_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_feature_stock_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_feature_stock_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_feature_stock_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_feature_stock_feature_id_seq TO staff;


--
-- Name: SEQUENCE stock_featuremap_stock_featuremap_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_featuremap_stock_featuremap_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_featuremap_stock_featuremap_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_featuremap_stock_featuremap_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_featuremap_stock_featuremap_id_seq TO staff;


--
-- Name: TABLE stock_featuremap; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_featuremap FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_featuremap FROM www;
GRANT ALL ON TABLE chado.stock_featuremap TO www;
GRANT ALL ON TABLE chado.stock_featuremap TO staff;


--
-- Name: TABLE stock_genotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_genotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_genotype FROM www;
GRANT ALL ON TABLE chado.stock_genotype TO www;
GRANT ALL ON TABLE chado.stock_genotype TO staff;


--
-- Name: SEQUENCE stock_genotype_stock_genotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_genotype_stock_genotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_genotype_stock_genotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_genotype_stock_genotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_genotype_stock_genotype_id_seq TO staff;


--
-- Name: SEQUENCE stock_library_stock_library_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_library_stock_library_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_library_stock_library_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_library_stock_library_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_library_stock_library_id_seq TO staff;


--
-- Name: TABLE stock_library; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_library FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_library FROM www;
GRANT ALL ON TABLE chado.stock_library TO www;
GRANT ALL ON TABLE chado.stock_library TO staff;


--
-- Name: TABLE stock_organism; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_organism FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_organism FROM www;
GRANT ALL ON TABLE chado.stock_organism TO www;
GRANT ALL ON TABLE chado.stock_organism TO staff;


--
-- Name: SEQUENCE stock_organism_stock_organism_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_organism_stock_organism_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_organism_stock_organism_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_organism_stock_organism_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_organism_stock_organism_id_seq TO staff;


--
-- Name: TABLE stock_phenotype; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_phenotype FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_phenotype FROM www;
GRANT ALL ON TABLE chado.stock_phenotype TO www;
GRANT ALL ON TABLE chado.stock_phenotype TO staff;


--
-- Name: SEQUENCE stock_phenotype_stock_phenotype_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_phenotype_stock_phenotype_id_seq TO staff;


--
-- Name: TABLE stock_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_pub FROM www;
GRANT ALL ON TABLE chado.stock_pub TO www;
GRANT ALL ON TABLE chado.stock_pub TO staff;


--
-- Name: SEQUENCE stock_pub_stock_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_pub_stock_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_pub_stock_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_pub_stock_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_pub_stock_pub_id_seq TO staff;


--
-- Name: TABLE stock_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_relationship FROM www;
GRANT ALL ON TABLE chado.stock_relationship TO www;
GRANT ALL ON TABLE chado.stock_relationship TO staff;


--
-- Name: TABLE stock_relationship_cvterm; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_relationship_cvterm FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_relationship_cvterm FROM www;
GRANT ALL ON TABLE chado.stock_relationship_cvterm TO www;
GRANT ALL ON TABLE chado.stock_relationship_cvterm TO staff;


--
-- Name: SEQUENCE stock_relationship_cvterm_stock_relationship_cvterm_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_relationship_cvterm_stock_relationship_cvterm_id_seq TO staff;


--
-- Name: TABLE stock_relationship_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_relationship_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_relationship_pub FROM www;
GRANT ALL ON TABLE chado.stock_relationship_pub TO www;
GRANT ALL ON TABLE chado.stock_relationship_pub TO staff;


--
-- Name: SEQUENCE stock_relationship_pub_stock_relationship_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_relationship_pub_stock_relationship_pub_id_seq TO staff;


--
-- Name: SEQUENCE stock_relationship_stock_relationship_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_relationship_stock_relationship_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_relationship_stock_relationship_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_relationship_stock_relationship_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_relationship_stock_relationship_id_seq TO staff;


--
-- Name: TABLE stock_search; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stock_search FROM PUBLIC;
REVOKE ALL ON TABLE chado.stock_search FROM www;
GRANT ALL ON TABLE chado.stock_search TO www;
GRANT ALL ON TABLE chado.stock_search TO staff;


--
-- Name: SEQUENCE stock_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stock_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stock_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stock_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stock_stock_id_seq TO staff;


--
-- Name: TABLE stockcollection; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockcollection FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockcollection FROM www;
GRANT ALL ON TABLE chado.stockcollection TO www;
GRANT ALL ON TABLE chado.stockcollection TO staff;


--
-- Name: SEQUENCE stockcollection_db_stockcollection_db_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockcollection_db_stockcollection_db_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockcollection_db_stockcollection_db_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockcollection_db_stockcollection_db_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockcollection_db_stockcollection_db_id_seq TO staff;


--
-- Name: TABLE stockcollection_db; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockcollection_db FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockcollection_db FROM www;
GRANT ALL ON TABLE chado.stockcollection_db TO www;
GRANT ALL ON TABLE chado.stockcollection_db TO staff;


--
-- Name: TABLE stockcollection_stock; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockcollection_stock FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockcollection_stock FROM www;
GRANT ALL ON TABLE chado.stockcollection_stock TO www;
GRANT ALL ON TABLE chado.stockcollection_stock TO staff;


--
-- Name: SEQUENCE stockcollection_stock_stockcollection_stock_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockcollection_stock_stockcollection_stock_id_seq TO staff;


--
-- Name: SEQUENCE stockcollection_stockcollection_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockcollection_stockcollection_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockcollection_stockcollection_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockcollection_stockcollection_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockcollection_stockcollection_id_seq TO staff;


--
-- Name: TABLE stockcollectionprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockcollectionprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockcollectionprop FROM www;
GRANT ALL ON TABLE chado.stockcollectionprop TO www;
GRANT ALL ON TABLE chado.stockcollectionprop TO staff;


--
-- Name: SEQUENCE stockcollectionprop_stockcollectionprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockcollectionprop_stockcollectionprop_id_seq TO staff;


--
-- Name: TABLE stockprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockprop FROM www;
GRANT ALL ON TABLE chado.stockprop TO www;
GRANT ALL ON TABLE chado.stockprop TO staff;


--
-- Name: TABLE stockprop_pub; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.stockprop_pub FROM PUBLIC;
REVOKE ALL ON TABLE chado.stockprop_pub FROM www;
GRANT ALL ON TABLE chado.stockprop_pub TO www;
GRANT ALL ON TABLE chado.stockprop_pub TO staff;


--
-- Name: SEQUENCE stockprop_pub_stockprop_pub_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockprop_pub_stockprop_pub_id_seq TO staff;


--
-- Name: SEQUENCE stockprop_stockprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.stockprop_stockprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.stockprop_stockprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.stockprop_stockprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.stockprop_stockprop_id_seq TO staff;


--
-- Name: TABLE study; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.study FROM PUBLIC;
REVOKE ALL ON TABLE chado.study FROM www;
GRANT ALL ON TABLE chado.study TO www;
GRANT ALL ON TABLE chado.study TO staff;


--
-- Name: TABLE study_assay; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.study_assay FROM PUBLIC;
REVOKE ALL ON TABLE chado.study_assay FROM www;
GRANT ALL ON TABLE chado.study_assay TO www;
GRANT ALL ON TABLE chado.study_assay TO staff;


--
-- Name: SEQUENCE study_assay_study_assay_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.study_assay_study_assay_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.study_assay_study_assay_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.study_assay_study_assay_id_seq TO www;
GRANT ALL ON SEQUENCE chado.study_assay_study_assay_id_seq TO staff;


--
-- Name: SEQUENCE study_study_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.study_study_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.study_study_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.study_study_id_seq TO www;
GRANT ALL ON SEQUENCE chado.study_study_id_seq TO staff;


--
-- Name: TABLE studydesign; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studydesign FROM PUBLIC;
REVOKE ALL ON TABLE chado.studydesign FROM www;
GRANT ALL ON TABLE chado.studydesign TO www;
GRANT ALL ON TABLE chado.studydesign TO staff;


--
-- Name: SEQUENCE studydesign_studydesign_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studydesign_studydesign_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studydesign_studydesign_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studydesign_studydesign_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studydesign_studydesign_id_seq TO staff;


--
-- Name: TABLE studydesignprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studydesignprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.studydesignprop FROM www;
GRANT ALL ON TABLE chado.studydesignprop TO www;
GRANT ALL ON TABLE chado.studydesignprop TO staff;


--
-- Name: SEQUENCE studydesignprop_studydesignprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studydesignprop_studydesignprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studydesignprop_studydesignprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studydesignprop_studydesignprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studydesignprop_studydesignprop_id_seq TO staff;


--
-- Name: TABLE studyfactor; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studyfactor FROM PUBLIC;
REVOKE ALL ON TABLE chado.studyfactor FROM www;
GRANT ALL ON TABLE chado.studyfactor TO www;
GRANT ALL ON TABLE chado.studyfactor TO staff;


--
-- Name: SEQUENCE studyfactor_studyfactor_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studyfactor_studyfactor_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studyfactor_studyfactor_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studyfactor_studyfactor_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studyfactor_studyfactor_id_seq TO staff;


--
-- Name: TABLE studyfactorvalue; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studyfactorvalue FROM PUBLIC;
REVOKE ALL ON TABLE chado.studyfactorvalue FROM www;
GRANT ALL ON TABLE chado.studyfactorvalue TO www;
GRANT ALL ON TABLE chado.studyfactorvalue TO staff;


--
-- Name: SEQUENCE studyfactorvalue_studyfactorvalue_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studyfactorvalue_studyfactorvalue_id_seq TO staff;


--
-- Name: TABLE studyprop; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studyprop FROM PUBLIC;
REVOKE ALL ON TABLE chado.studyprop FROM www;
GRANT ALL ON TABLE chado.studyprop TO www;
GRANT ALL ON TABLE chado.studyprop TO staff;


--
-- Name: TABLE studyprop_feature; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.studyprop_feature FROM PUBLIC;
REVOKE ALL ON TABLE chado.studyprop_feature FROM www;
GRANT ALL ON TABLE chado.studyprop_feature TO www;
GRANT ALL ON TABLE chado.studyprop_feature TO staff;


--
-- Name: SEQUENCE studyprop_feature_studyprop_feature_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studyprop_feature_studyprop_feature_id_seq TO staff;


--
-- Name: SEQUENCE studyprop_studyprop_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.studyprop_studyprop_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.studyprop_studyprop_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.studyprop_studyprop_id_seq TO www;
GRANT ALL ON SEQUENCE chado.studyprop_studyprop_id_seq TO staff;


--
-- Name: SEQUENCE synonym_synonym_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.synonym_synonym_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.synonym_synonym_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.synonym_synonym_id_seq TO www;
GRANT ALL ON SEQUENCE chado.synonym_synonym_id_seq TO staff;


--
-- Name: TABLE tableinfo; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tableinfo FROM PUBLIC;
REVOKE ALL ON TABLE chado.tableinfo FROM www;
GRANT ALL ON TABLE chado.tableinfo TO www;
GRANT ALL ON TABLE chado.tableinfo TO staff;


--
-- Name: SEQUENCE tableinfo_tableinfo_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.tableinfo_tableinfo_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.tableinfo_tableinfo_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.tableinfo_tableinfo_id_seq TO www;
GRANT ALL ON SEQUENCE chado.tableinfo_tableinfo_id_seq TO staff;


--
-- Name: TABLE tmp; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tmp FROM PUBLIC;
REVOKE ALL ON TABLE chado.tmp FROM www;
GRANT ALL ON TABLE chado.tmp TO www;
GRANT ALL ON TABLE chado.tmp TO sdash;
GRANT ALL ON TABLE chado.tmp TO staff;


--
-- Name: TABLE tmp_cds_handler; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tmp_cds_handler FROM PUBLIC;
REVOKE ALL ON TABLE chado.tmp_cds_handler FROM www;
GRANT ALL ON TABLE chado.tmp_cds_handler TO www;
GRANT ALL ON TABLE chado.tmp_cds_handler TO staff;


--
-- Name: SEQUENCE tmp_cds_handler_cds_row_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.tmp_cds_handler_cds_row_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.tmp_cds_handler_cds_row_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.tmp_cds_handler_cds_row_id_seq TO www;
GRANT ALL ON SEQUENCE chado.tmp_cds_handler_cds_row_id_seq TO staff;


--
-- Name: TABLE tmp_cds_handler_relationship; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tmp_cds_handler_relationship FROM PUBLIC;
REVOKE ALL ON TABLE chado.tmp_cds_handler_relationship FROM www;
GRANT ALL ON TABLE chado.tmp_cds_handler_relationship TO www;
GRANT ALL ON TABLE chado.tmp_cds_handler_relationship TO staff;


--
-- Name: SEQUENCE tmp_cds_handler_relationship_rel_row_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq TO www;
GRANT ALL ON SEQUENCE chado.tmp_cds_handler_relationship_rel_row_id_seq TO staff;


--
-- Name: SEQUENCE tmp_temp_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.tmp_temp_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.tmp_temp_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.tmp_temp_id_seq TO www;
GRANT ALL ON SEQUENCE chado.tmp_temp_id_seq TO staff;


--
-- Name: TABLE treatment; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.treatment FROM PUBLIC;
REVOKE ALL ON TABLE chado.treatment FROM www;
GRANT ALL ON TABLE chado.treatment TO www;
GRANT ALL ON TABLE chado.treatment TO staff;


--
-- Name: SEQUENCE treatment_treatment_id_seq; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON SEQUENCE chado.treatment_treatment_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE chado.treatment_treatment_id_seq FROM www;
GRANT ALL ON SEQUENCE chado.treatment_treatment_id_seq TO www;
GRANT ALL ON SEQUENCE chado.treatment_treatment_id_seq TO staff;


--
-- Name: TABLE tripal_gff_temp; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tripal_gff_temp FROM PUBLIC;
REVOKE ALL ON TABLE chado.tripal_gff_temp FROM www;
GRANT ALL ON TABLE chado.tripal_gff_temp TO www;


--
-- Name: TABLE tripal_gffcds_temp; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tripal_gffcds_temp FROM PUBLIC;
REVOKE ALL ON TABLE chado.tripal_gffcds_temp FROM www;
GRANT ALL ON TABLE chado.tripal_gffcds_temp TO www;
GRANT ALL ON TABLE chado.tripal_gffcds_temp TO staff;


--
-- Name: TABLE tripal_gffprotein_temp; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tripal_gffprotein_temp FROM PUBLIC;
REVOKE ALL ON TABLE chado.tripal_gffprotein_temp FROM www;
GRANT ALL ON TABLE chado.tripal_gffprotein_temp TO www;
GRANT ALL ON TABLE chado.tripal_gffprotein_temp TO staff;


--
-- Name: TABLE tripal_obo_temp; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.tripal_obo_temp FROM PUBLIC;
REVOKE ALL ON TABLE chado.tripal_obo_temp FROM www;
GRANT ALL ON TABLE chado.tripal_obo_temp TO www;
GRANT ALL ON TABLE chado.tripal_obo_temp TO staff;


--
-- Name: TABLE type_feature_count; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.type_feature_count FROM PUBLIC;
REVOKE ALL ON TABLE chado.type_feature_count FROM www;
GRANT ALL ON TABLE chado.type_feature_count TO www;
GRANT ALL ON TABLE chado.type_feature_count TO staff;


--
-- Name: TABLE view_citation; Type: ACL; Schema: chado; Owner: www
--

REVOKE ALL ON TABLE chado.view_citation FROM PUBLIC;
REVOKE ALL ON TABLE chado.view_citation FROM www;
GRANT ALL ON TABLE chado.view_citation TO www;
GRANT ALL ON TABLE chado.view_citation TO staff;


--
-- PostgreSQL database dump complete
--

