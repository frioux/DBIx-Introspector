package DBIx::Introspector;

use Moo;
use DBIx::Introspector::Driver;

has _drivers => (
   is => 'ro',
   init_arg => 'drivers',
   builder => '_build_drivers',
   lazy => 1,
);

sub _build_drivers {
   return [ map DBIx::Introspector::Driver->new($_),
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
      { name => 'ACCESS',      parents => ['DBI'] },
      { name => 'DB2',         parents => ['DBI'] },
      { name => 'Informix',    parents => ['DBI'] },
      { name => 'InterBase',   parents => ['DBI'] },
      { name => 'MSSQL',       parents => ['DBI'] },
      { name => 'Oracle',      parents => ['DBI'] },
      { name => 'Pg',          parents => ['DBI'] },
      { name => 'SQLAnywhere', parents => ['DBI'] },
      { name => 'SQLite',      parents => ['DBI'] },
      { name => 'Sybase',      parents => ['DBI'] },
      { name => 'mysql',       parents => ['DBI'] },
      { name => 'Firebird::Common',    parents => ['Interbase'] },
      { name => 'Firebird',    parents => ['Interbase'] },
      {
         name => 'ODBC',
         dbh_determination_strategy => sub {
            my $v = $_[0]->_get_info_from_dbh($_[1], 'SQL_DBMS_NAME');
            $v =~ s/\W/_/g;
            "ODBC_$v"
         },
         parents => ['DBI'],
      },
      { name => 'ODBC_ACCESS',               parents => ['ACCESS', 'ODBC'] },
      { name => 'ODBC_DB2_400_SQL',          parents => ['DB2', 'ODBC'] },
      { name => 'ODBC_Firebird',             parents => ['Firebird::Common', 'ODBC'] },
      { name => 'ODBC_Microsoft_SQL_Server', parents => ['MSSQL', 'ODBC'] },
      { name => 'ODBC_SQL_Anywhere',         parents => ['SQLAnywhere', 'ODBC'] },
      {
         name => 'ADO',
         dbh_determination_strategy => sub {
            my $v = $_[0]->_get_info_from_dbh($_[1], 'SQL_DBMS_NAME');
            $v =~ s/\W/_/g;
            "ADO_$v"
         },
         parents => ['DBI'],
      },
      { name => 'ADO_MS_Jet',               parents => ['ACCESS', 'ADO'] },
      { name => 'ADO_Microsoft_SQL_Server', parents => ['MSSQL', 'ADO'] },
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

   $self->_clear_drivers_by_name;
   # check for dupes?
   push @{$self->_drivers}, DBIx::Introspector::Driver->new($driver)
}

sub replace_driver {
   my ($self, $driver) = @_;

   $self->_clear_drivers_by_name;
   @{$self->_drivers} = (
      (grep $_ ne $driver->{name}, @{$self->_drivers}),
      DBIx::Introspector::Driver->new($driver)
   );
}

sub decorate_driver_dsn {
   my ($self, $name, $key, $value) = @_;

   if (my $d = $self->_drivers_by_name->{$name}) {
      $d->_add_dsn_option($key => $value)
   } else {
      die "no such driver <$name>"
   }
}

sub decorate_driver_dbh {
   my ($self, $name, $key, $value) = @_;

   if (my $d = $self->_drivers_by_name->{$name}) {
      $d->_add_dbh_option($key => $value)
   } else {
      die "no such driver <$name>"
   }
}

sub get {
   my ($self, $dbh, $dsn, $key, $opt) = @_;
   $opt ||= {};

   my @args = (
      drivers_by_name => $self->_drivers_by_name,
      key => $key
   );

   if ($dbh and my $driver = $self->_driver_for((ref $dbh eq 'CODE' ? $dbh->() : $dbh), $dsn)) {
      my $ret = $driver
         ->_get_via_dbh({
            dbh => $dbh,
            @args,
         });
      return $ret if defined $ret;
      $ret = $driver
         ->_get_via_dsn({
            dsn => $dsn,
            @args,
         });
      return $ret if defined $ret;
   }

   my $dsn_ret = $self->_driver_for($dbh, $dsn)
      ->_get_via_dsn({
         dsn => $dsn,
         @args,
      }) if $dsn;
   return $dsn_ret if defined $dsn_ret;

   if (ref $dbh eq 'CODE' && ref $opt->{dbh_fallback_connect} eq 'CODE') {
      $opt->{dbh_fallback_connect}->();
      my $dbh = $dbh->();
      return $self->_driver_for($dbh, $dsn)
         ->_get_via_dbh({
            dbh => $dbh,
            @args,
         })
   }

   die "wtf"
}

sub _driver_for {
   my ($self, $dbh, $dsn) = @_;

   my $driver = $self->_root_driver;
   my $done;

   DETECT:
   do {
      $done = $driver->_determine($dbh, $dsn);
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
