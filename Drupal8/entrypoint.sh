#!/usr/bin/env sh
# Drupal Install
sleep 5

drush site-install -y \
  --db-url=pgsql://postgres:example@drupal8_db_1:5432/drupal \
  --account-mail="admin@example.com" \
  --account-name=admin \
  --account-pass=admin \
  --site-mail="admin@example.com" \
  --site-name="Drupal D8"
