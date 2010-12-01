package WWW::LacunaExpanse::Schema;

use Modern::Perl;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces (
    result_namespace            => 'Result',
    resultset_namespace         => 'ResultSet',
    default_resultset_class     => '+DBIx::Class::ResultSet',
);

1;
