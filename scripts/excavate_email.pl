#!/home/icydee/localperl/bin/perl

# Script to read the emails and process the responses for
# excavators
#
# NOTE:
#
# This script can be quite expensive on requests so it is probably best to only
# run it one or two times a day.
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::Schema;
use WWW::LacunaExpanse::API::DateTime;

#### Configuration ####
my $username                = 'icydee';
my $password                = 'secret';

my $uri                     = 'https://us1.lacunaexpanse.com';
my $dsn                     = "dbi:SQLite:dbname=$Bin/../db/lacuna.db";

#### End of Configuration ####

my $schema = WWW::LacunaExpanse::Schema->connect($dsn);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $uri,
    username    => $username,
    password    => $password,
});

# Read all emails, print the subjects

my $inbox       = $api->inbox;
my $my_empire   = $api->my_empire;

my $excavator_messages = {
    'Glyph Discovered!'         => 1,
    'Resources Discovered!'     => 2,
    'Excavator Found Nothing'   => 3,
    'Excavator Uncovered Plan'  => 4,
};

print "inbox = $inbox\n";

my @archive_messages;

$inbox->reset_message;
MESSAGE:
while (my $message = $inbox->next_message) {
    # Look only for messages from me, to me
    if ($message->from_id == $my_empire->id && $message->to_id == $my_empire->id) {
        if ($excavator_messages->{$message->subject}) {
            print $message->date." ".$message->subject."\n";
#            print $message->body."\n";
            $excavator_messages->{$message->subject}++;

            my ($starmap) = $message->body
                =~ m/\{(Starmap.*)\}/;

            my ($planet) = $message->body
                =~ m/\{(Planet.*)\}/;

            my ($quantity, $resource) = $message->body
                =~ m/it did find (\d*)\W(\w*)/;
            my ($glyph) = $message->body
                =~ m/entirely of (\w*)/;
            my ($plan, $level)  = $message->body
                =~ m/a level (\d*)\s(.*?)\./;

            $starmap    = $starmap  || '';
            $quantity   = $quantity || '';
            $resource   = $resource || '';
            $glyph      = $glyph    || '';
            $plan       = $plan     || '';
            $level      = $level    || '';
            my $body_db;

            # Get the ID of the body
            if ($starmap) {
                my ($star_x, $star_y, $body) = $starmap =~ m/(-?\d+)\s(-?\d+)\s(.*?)\}/;
#                print "Star [$star_x][$star_y] body [$body]\n";
                # Quicker to search the database rather than an API call
                ($body_db) = $schema->resultset('Body')->search({name => $body});
                if (! $body_db) {
                    print "ERROR: Cannot find ($body) in the database\n";
                }
            }

            if (! $body_db) {
                # Failed to find the body ID (perhaps the body has since been renamed)
            }
            elsif ($planet && ! $starmap) {
                # Found by the archaeology ministry itself
            }
            elsif (! $resource && ! $glyph && ! $plan) {
                # Found nothing
                $schema->resultset('Excavation')->create({
                    body_id         => $body_db->id,
                    on_date         => WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string($message->date),
                    resource_genre  => 'nothing',
                    resource_type   => '',
                    resource_qty    => '',
                });
                push @archive_messages, $message->id;
            }
            elsif ($quantity && $resource) {
                # Found resource
                $schema->resultset('Excavation')->create({
                    body_id         => $body_db->id,
                    on_date         => WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string($message->date),
                    resource_genre  => 'resource',
                    resource_type   => $resource,
                    resource_qty    => $quantity,
                });
                push @archive_messages, $message->id;
            }
            elsif ($plan) {
                # Found plan
                $schema->resultset('Excavation')->create({
                    body_id         => $body_db->id,
                    on_date         => WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string($message->date),
                    resource_genre  => 'plan',
                    resource_type   => $plan,
                    resource_qty    => $level,
                });
                push @archive_messages, $message->id;
            }
            elsif ($glyph) {
                # Found glyph
                $schema->resultset('Excavation')->create({
                    body_id         => $body_db->id,
                    on_date         => WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string($message->date),
                    resource_genre  => 'glyph',
                    resource_type   => $glyph,
                    resource_qty    => '',
                });
                push @archive_messages, $message->id;
            }
#            print "Starmap [$starmap] planet [$planet] quantity [$quantity] resource [$resource] glyph [$glyph] plan [$plan]\n";
        }
        else {
            print $message->date." ??? ".$message->subject."\n";
#               push @archive_messages, $message->id;
        }
    }
#    else {
#        print $message->date." >>> ".$message->subject."\n";
#    }
}

$inbox->archive_messages(\@archive_messages);

for my $key (keys %$excavator_messages) {
    print $excavator_messages->{$key}, "\t found $key\n";
}



1;
