#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use DBIx::Introspector;
use DBI;

my $d = DBIx::Introspector->new(
   drivers => [ map DBIx::Introspector::Driver->new($_),
      {
         name => 'DBI',
         dbh_determination_strategy => sub { $_[1]->{Driver}{Name} },
         dsn_determination_strategy => sub {
            my $dsn = $_[1] || $ENV{DBI_DSN} || '';
            my ($driver) = $dsn =~ /dbi:([^:]+):/i;
            $driver ||= $ENV{DBI_DRIVER};
            return $driver
         },
      },
      {
         name => 'SQLite',
         parents => ['DBI'],
         dbh_determination_strategy => sub {
            my ($v) = $_[1]->selectrow_array('SELECT "value" FROM "a"');
            return "SQLite$v"
         },
      },
      { name => 'SQLite1', parents => ['SQLite'] },
      { name => 'SQLite2', parents => ['SQLite'] },
   ]
);

$d->add_driver({ name => 'SQLite3', parents => ['SQLite'] });

my $dbh = DBI->connect('dbi:SQLite::memory:');
$dbh->do($_) for (
   'CREATE TABLE "a" ("value" NOT NULL)',
   'INSERT INTO "a" ("value") VALUES (1)',
);

is($d->get($dbh, 'dbi:SQLite::memory:', '_introspector_driver'), 'SQLite1');
is($d->get($dbh, 'dbi:SQLite::memory:', 'foo'), '');
$d->replace_driver({
   name => 'SQLite1',
   parents => ['SQLite'],
   options => {
      foo => sub { 'bar' },
   },
});
is($d->get($dbh, 'dbi:SQLite::memory:', 'foo'), 'bar');
$dbh->do('UPDATE "a" SET "value" = 2');
is($d->get($dbh, 'dbi:SQLite::memory:', '_introspector_driver'), 'SQLite2');

done_testing;
