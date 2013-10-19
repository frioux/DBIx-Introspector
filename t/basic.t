#!/usr/bin/env perl

use Test::Roo;
use DBI;
use DBIx::Introspector;

has [qw(dsn user password rdbms_engine introspector_driver)]
   => ( is => 'ro' );

test basic => sub {
   my $self = shift;

   my $d = DBIx::Introspector->new();

   my $dbh = DBI->connect($self->dsn);
   is(
      $d->get($dbh, '_introspector_driver'),
      $self->introspector_driver,
      'introspector driver'
   );

   # is($d->_storage->rdbms_engine, $self->rdbms_engine, 'engine');
};

run_me('ODBC SQL Server', {
   rdbms_engine => 'SQL Server',
   dsn => $ENV{ODBC_MSSQL_DSN},
   introspector_driver => 'ODBC_Microsoft_SQL_Server',
}) if $ENV{ODBC_MSSQL_DSN};

run_me(SQLite => {
   rdbms_engine => 'SQLite',
   introspector_driver => 'SQLite',
   dsn => 'dbi:SQLite::memory:',
});

done_testing;

