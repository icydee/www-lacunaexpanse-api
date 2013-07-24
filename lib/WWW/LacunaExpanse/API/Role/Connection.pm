package WWW::LacunaExpanse::API::Role::Connection;

use Moose::Role;
use Data::Dumper;

use WWW::LacunaExpanse::API::Connection;

has 'connection'        => (is => 'ro', lazy_build => 1);

sub _build_connection {
    return WWW::LacunaExpanse::API::Connection->instance;
}

# Create attributes for the class based on the 'attributes' hash
#
sub create_attributes {
    my ($class, $attributes) = @_;

    # Create object attributes.
    for my $attr (keys %$attributes) {
        my $isa = $attributes->{$attr};
        $isa = $$isa if ref $isa eq 'SCALAR';
    
        $class->meta->add_attribute($attr,(
            is  => 'ro',
            isa => $isa,
            writer  => "_$attr", lazy_build => 1,
        ));
        # Make them lazy with an update method.
        $class->meta()->add_method(
            "_build_$attr" => sub {
                my ($self) = @_;
                $self->update;
                return $self->$attr;
            }
        );
    }
}

# Create a new instance of the object from a raw hash of values
# 
sub new_from_raw {
    my ($class, $raw) = @_;

    my $self = $class->new;
    $self->update_from_raw($raw);
    return $self;
}

# Update an existing instance of the object from a raw hash of values
#
sub update_from_raw {
    my ($self, $raw) = @_;

    my $hashref = $raw;

    my $attributes = $self->_attributes;
    KEY:
    for my $key (keys %$hashref) {
        if (not defined $attributes->{$key}) {
            print STDERR "Unknown value in hashref [$key]\n";
            #confess "Unknown value in hashref [$key]";
            next KEY;
        }
        my $writer = "_$key";
        if (ref $attributes->{$key} eq 'SCALAR') {
            my $class = ${$attributes->{$key}};
            my $type = '';
            if ($class =~ m/ArrayRef\[/) {
                $class =~ s/^ArrayRef\[(.*)\]$/$1/;
                $type = 'ArrayRef';
            }
            elsif ($class =~ m/HashRef\[/) {
                $class =~ s/^HashRef\[(.*)\]$/$1/;
                $type = 'HashRef';
            }
            eval "require $class";
            if ($type eq 'ArrayRef') {
                my $objects;
                for my $hash (@{$hashref->{$key}}) {
                    my $object = $class->new_from_raw($hash);
                    push @$objects,$object;
                }
                $self->$writer($objects);
            }
            elsif ($type eq 'HashRef') {
                my $objects;
                for my $k (keys %{$hashref->{$key}}) {
                    $objects->{$k} = $class->new_from_raw($hashref->{$key}{$k});
                }
                $self->$writer($objects);
            }
            else {
                my $object = $class->new_from_raw($hashref->{$key});
                $self->$writer($object);
            }
        }
        else {
            $self->$writer($hashref->{$key});
        }
    }
}

1
