#!/usr/bin/env perl

use Test::Roo;
use DBI;
use DBIx::Introspector;

has [qw(
   dsn user password rdbms_engine
   dbh_introspector_driver dsn_introspector_driver
)] => ( is => 'ro' );

test basic => sub {
   my $self = shift;

   my $d = DBIx::Introspector->new();

   is(
      $d->get(undef, $self->dsn, '_introspector_driver'),
      $self->dsn_introspector_driver,
      'dsn introspector driver'
   );
   my $dbh = DBI->connect($self->dsn, $self->user, $self->password);
   is(
      $d->get($dbh, $self->dsn, '_introspector_driver'),
      $self->dbh_introspector_driver,
      'dbh introspector driver'
   );
};

run_me(SQLite => {
   dbh_introspector_driver => 'SQLite',
   dsn_introspector_driver => 'SQLite',
   dsn => 'dbi:SQLite::memory:',
});

run_me('ODBC SQL Server', {
   dsn      => $ENV{DBIITEST_ODBC_MSSQL_DSN},
   user     => $ENV{DBIITEST_ODBC_MSSQL_USER},
   password => $ENV{DBIITEST_ODBC_MSSQL_PASSWORD},

   dbh_introspector_driver => 'ODBC_Microsoft_SQL_Server',
   dsn_introspector_driver => 'ODBC',
}) if $ENV{DBIITEST_ODBC_MSSQL_DSN};

run_me(Pg => {
   dsn      => $ENV{DBIITEST_PG_DSN},
   user     => $ENV{DBIITEST_PG_USER},
   password => $ENV{DBIITEST_PG_PASSWORD},

   dbh_introspector_driver => 'Pg',
   dsn_introspector_driver => 'Pg',
}) if $ENV{DBIITEST_PG_DSN};

run_me(mysql => {
   dsn      => $ENV{DBIITEST_MYSQL_DSN},
   user     => $ENV{DBIITEST_MYSQL_USER},
   password => $ENV{DBIITEST_MYSQL_PASSWORD},

   dbh_introspector_driver => 'mysql',
   dsn_introspector_driver => 'mysql',
}) if $ENV{DBIITEST_MYSQL_DSN};

done_testing;

