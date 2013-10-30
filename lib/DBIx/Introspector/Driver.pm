package
   DBIx::Introspector::Driver;

use Moo;

has name => (
   is => 'ro',
   required => 1,
);

has _dbh_determination_strategy => (
   is => 'ro',
   default => sub { sub { 1 } },
   init_arg => 'dbh_determination_strategy',
);

has _dsn_determination_strategy => (
   is => 'ro',
   default => sub { sub { 1 } },
   init_arg => 'dsn_determination_strategy',
);

has _options => (
   is => 'ro',
   builder => sub { 
      +{
         _introspector_driver => sub { $_[0]->name },
      }
   },
   init_arg => 'options',
);

has _parents => (
   is => 'ro',
   default => sub { +[] },
   init_arg => 'parents',
);

sub _add_option {
   my ($self, $key, $value) = @_;

   $self->_options->{$key} = $value
}

sub _determine {
   my ($self, $dbh, $dsn) = @_;

   my $dbh_strategy = $self->_dbh_determination_strategy;

   return $self->$dbh_strategy($dbh) if $dbh;

   my $dsn_strategy = $self->_dsn_determination_strategy;
   $self->$dsn_strategy($dsn)
}

sub _get {
   my ($self, $dbh, $drivers_by_name, $key) = @_;

   my $option = $self->_options->{$key};

   if ($option && ref $option && ref $option eq 'CODE') {
      return $option->(@_)
   }
   elsif ($option and my $driver = $drivers_by_name->{$option}) {
      $driver->_get($dbh, $drivers_by_name, $key)
   }
   elsif (@{$self->_parents}) {
      my @p = @{$self->_parents};
      for my $parent (@p) {
         my $driver = $drivers_by_name->{$parent};
         die "no such driver <$parent>" unless $driver;
         my $ret = $driver->_get($dbh, $drivers_by_name, $key);
         return $ret if $ret
      }
   }
   else {
      return undef
   }
}

sub _get_info_from_dbh {
  my ($self, $dbh, $info) = @_;

  if ($info =~ /[^0-9]/) {
    require DBI::Const::GetInfoType;
    $info = $DBI::Const::GetInfoType::GetInfoType{$info};
    die "Info type '$_[1]' not provided by DBI::Const::GetInfoType"
      unless defined $info;
  }

  $dbh->get_info($info);
}

1;
