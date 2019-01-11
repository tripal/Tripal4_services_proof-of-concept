<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Gene extends Model
{
    protected $fillable = [
        'name',
        'residue',
        'type'
    ];
}
