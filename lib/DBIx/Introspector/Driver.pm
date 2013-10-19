package
   DBIx::Introspector::Driver;

use Moo;

has name => (
   is => 'ro',
   required => 1,
);

has _determination_strategy => (
   is => 'ro',
   default => sub { sub { 1 } },
   init_arg => 'determination_strategy',
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

sub _add_option { shift->_options->{shift @_} = shift }

sub _determine {
   my ($self, $dbh) = @_;

   my $strategy = $self->_determination_strategy;

   $self->$strategy($dbh)
}

sub _get {
   my ($self, $dbh, $drivers_by_name, $key) = @_;

   my $option = $self->_options->{$key};

   if ($option && ref $option && ref $option eq 'CODE') {
      return $option->(@_)
   }
   elsif ($option and my $driver = $drivers_by_name->{$option}) {
      $driver->_get(@_)
   }
   elsif (@{$self->_parents}) {
      my @p = @{$self->_parents};
      for my $parent (@p) {
         my $ret = $parent->_get(@_);
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
