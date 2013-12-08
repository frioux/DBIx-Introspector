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

__END__

=pod

=head1 SYNOPSIS

 my $d = DBIx::Introspector->new;

 # standard dialects
 $d->decorate_driver_dsn(Pg     => concat_sql => '? || ?');
 $d->decorate_driver_dsn(SQLite => concat_sql => '? || ?');

 # non-standard
 $d->decorate_driver_dsn(MSSQL  => concat_sql => '? + ?');
 $d->decorate_driver_dsn(mysql  => concat_sql => 'CONCAT( ?, ? )');

 my $concat_sql = $d->get($dbh, $dsn, 'concat_sql');

=head1 DESCRIPTION

C<DBIx::Introspector> is a module factored out of the L<DBIx::Class> database
detection code.  Most code that needs to detect which database it is connected
to assumes that there is a one-to-one mapping from database drivers to database
engines.  Unfortunately reality is rarely that simple.  For instance,
L<DBD::ODBC> is typically used to connect to SQL Server, but ODBC can be used to
connect to PostgreSQL, MySQL, and Oracle.  Additionally, while ODBC is the most
common way to connect to SQL Server, it is not the only option, as L<DBD::ADO>
can also be used.

C<DBIx::Introspector> can correctly detect which database you are connected to,
because it was factor out of a complex, working codebase.  On top of that it has
been written to be very extensible.  So if you needed to detect which version of
your given database you are connected to that would not be difficult.

Furthermore, C<DBIx::Introspector> does it's best to try to detect information
based on the dsn you give it if you have not yet connected, so you can possibly
avoid connection or at least defer connection.

=head1 METHODS

=head2 C<add_driver>

 $dbii->add_driver({
   name => 'Pg',
   parents => ['DBI'],
   dsn_options => {
      concat_sql => '? || ?',
      random_func => 'RANDOM()',
   })

Takes a hashref L<< defining a new driver | DRIVER DEFINITION >>.

=head2 C<replace_driver>

 $dbii->replace_driver({
   name => 'Pg',
   parents => ['DBI'],
   dsn_options => {
      concat_sql => '? || ?',
      random_func => 'RANDOM()',
   })

Takes a hashref L<< defining a new driver | DRIVER DEFINITION >>.  Replaces
the driver already defined with the same name.

=head2 C<decorate_driver_dbh>

 $dbii->decorate_driver_dbh('MSSQL', 'concat_sql', '? + ?')

Takes a C<driver name>, C<key> and a C<value>.  The C<key value> pair will
be inserted into the driver's C<dbh_options>.

=head2 C<decorate_driver_dsn>

 $dbii->decorate_driver_dsn('SQLite', 'concat_sql', '? || ?')

Takes a C<driver name>, C<key> and a C<value>.  The C<key value> pair will
be inserted into the driver's C<dsn_options>.

=head2 C<get>

 $dbii->get($dbh, $dsn, 'concat_sql')

Takes a C<dbh>, C<dsn>, C<key>, and optionally a hashref of C<options>.

The C<dbh> can be a coderef returning a C<dbh>.  If you provide the
C<dbh_fallback_connect> option it will be used to connect the C<dbh> if it is
not already connected and then queried, if the C<dsn> was insufficient.

So for example, I might do:

 my $dbh;
 $dbii->get(sub { $dbh }, $dsn, 'concat_sql', {
    dbh_fallback_connect => sub { $dbh = DBI->connect($dsn, $user, $pass) },
 });

Which will only connect if it has to, like if the user is using the C<DBD::ODBC>
driver to connect.

=head1 DRIVER DEFINITION

Drivers have the following six attributes

=head2 C<name>

Required.  Must be unique among the drivers contained in the introspector.

=head2 C<parents>

Arrayref of parent drivers.  This allows parent drivers to implement common
options among children.  So for example on might define a driver for each
version of PostgreSQL, and have a parent driver that they all use for common
base info.

=head2 C<dbh_determination_strategy>

This is a code reference that is called as a method on the driver with the
C<dbh> as the first argument.  It should return a driver name.

=head2 C<dsn_determination_strategy>

This is a code reference that is called as a method on the driver with the
C<dsn> as the first argument.  It should return a driver name.

=head2 C<dbh_options>

Hashref of C<< key value >> pairs for detecting information based on the
C<dbh>.  A value that is not a code reference is returned directly, though
I suggest non-coderefs all go in the L</dsn_options> so that they may be
used without connecting if possilbe.

If a code reference is passed it will get called as a method on the driver
with the following keys passed in a hash reference:

=over 2

=item C<key>

This is the name of the value that the user requested.

=item C<dbh>

This is the connected C<dbh> that you can use to introspect the database.

=item C<drivers_by_name>

You shouldn't use this, it's for internals.

=back

=head2 C<dsn_options>

Hashref of C<< key value >> pairs for detecting information based on the
C<dsn>.  A value that is not a code reference is returned directly.

If a code reference is passed it will get called as a method on the driver
with the following keys passed in a hash reference:

=over 2

=item C<key>

This is the name of the value that the user requested.

=item C<dsn>

This is the connected C<dsn> that you can use to introspect the database.

=item C<drivers_by_name>

You shouldn't use this, it's for internals.

=back

=cut
