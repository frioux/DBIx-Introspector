#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use DBIx::Introspector;

my $d = DBIx::Introspector->new();

# this would handily supplant this gross code:
# https://github.com/frioux/DBIx-Class-MaterializedPath/blob/master/lib/DBIx/Class/MaterializedPath.pm#L97
$d->decorate_driver(DBI => concat_sql => sub { '%s || %s' });
$d->decorate_driver(mysql => concat_sql => sub { 'CONCAT( %s, %s)' });
$d->decorate_driver(MSSQL => concat_sql => sub { '%s + %s' });
my $n = $d->_drivers_by_name;
is(
   $n->{'ODBC_Microsoft_SQL_Server'}->_get({
      drivers_by_name => $n,
      dbh => undef,
      key => 'concat_sql'
   }),
   '%s + %s',
   'ODBC_MSSQL "subclasses" MSSQL'
);

is(
   $d->_drivers_by_name->{'ADO_Microsoft_SQL_Server'}->_get({
      drivers_by_name => $n,
      dbh => undef,
      key => 'concat_sql'
   }),
   '%s + %s',
   'ADO_MSSQL "subclasses" MSSQL'
);

done_testing;

