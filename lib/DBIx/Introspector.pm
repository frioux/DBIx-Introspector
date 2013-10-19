package DBIx::Introspector;

use Moo;
use DBIx::Introspector::Driver;

has _drivers => (
   is => 'ro',
   builder => '_build_drivers',
   lazy => 1,
);

sub _build_drivers {
   return [ map DBIx::Introspector::Driver->new($_),
      {
         name => 'DBI',
         determination_strategy => sub { $_[1]->{Driver}{Name} },
      },
      { name => 'ACCESS',      parents => ['DBI'] },
      { name => 'DB2',         parents => ['DBI'] },
      { name => 'Informix',    parents => ['DBI'] },
      { name => 'InterBase',   parents => ['DBI'] },
      { name => 'MSSQL',       parents => ['DBI'] }, # 90% sure this is virtual
      { name => 'Oracle',      parents => ['DBI'] },
      { name => 'Pg',          parents => ['DBI'] },
      { name => 'SQLAnywhere', parents => ['DBI'] },
      { name => 'SQLite',      parents => ['DBI'] },
      { name => 'Sybase',      parents => ['DBI'] },
      { name => 'mysql',       parents => ['DBI'] },
      { name => 'Firebird',    parents => ['Interbase'] },
      {
         name => 'ODBC',
         determination_strategy => sub {
            my $v = $_[0]->_get_info_from_dbh($_[1], 'SQL_DBMS_NAME');
            $v =~ s/\W/_/g;
            "ODBC_$v"
         },
         parents => ['DBI'],
      },
      { name => 'ODBC_ACCESS',               parents => ['ODBC'] },
      { name => 'ODBC_DB2_400_SQL',          parents => ['ODBC'] },
      { name => 'ODBC_Firebird',             parents => ['ODBC'] },
      { name => 'ODBC_Microsoft_SQL_Server', parents => ['ODBC'] },
      { name => 'ODBC_SQL_Anywhere',         parents => ['ODBC'] },
      {
         name => 'ADO',
         determination_strategy => sub {
            my $v = $_[0]->_get_info_from_dbh($_[1], 'SQL_DBMS_NAME');
            $v =~ s/\W/_/g;
            "ADO_$v"
         },
         parents => ['DBI'],
      },
      { name => 'ADO_MS_Jet',               parents => ['ADO'] },
      { name => 'ADO_Microsoft_SQL_Server', parents => ['ADO'] },
   ]
}

sub _root_driver { shift->_drivers->[0] }

has _drivers_by_name => (
   is => 'ro',
   builder => sub { +{ map { $_->name => $_ } @{$_[0]->_drivers} } },
   clearer => '_clear_drivers_by_name',
   lazy => 1,
);

sub add_driver {
   my ($self, $driver) = @_;

   die "driver must be a DBIx::Driver" unless $driver->isa('DBIx::Driver');

   $self->_clear_drivers_by_name;
   push @{$self->_drivers}, $driver
}

sub decorate_driver {
   my ($self, $name, $key, $value) = @_;

   if (my $d = $self->_drivers_by_name->{$name}) {
      $d->_add_option($key => $value)
   } else {
      die "no such driver <$name>"
   }
}

sub get {
   my ($self, $dbh, $key) = @_;

   $self->_driver_for($dbh)
      ->_get($dbh, $self->_drivers_by_name, $key)
}

sub _driver_for {
   my ($self, $dbh) = @_;

   my $driver = $self->_root_driver;
   my $done;

   DETECT:
   do {
      $done = $driver->_determine($dbh);
      if (!defined $done) {
         die "cannot figure out wtf this is"
      } elsif ($done ne 1) {
         $driver = $self->_drivers_by_name->{$done}
            or die "no such driver <$done>"
      }
   } while $done ne 1;

   return $driver
}

1;
