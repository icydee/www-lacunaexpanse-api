#!/home/icydee/localperl/bin/perl

# Script to read the emails and process the responses for
# excavators
#
# Emails relating to the returns made from excavators are processed and the
# type of return (nothing/resource/glyph/plan) is put in the database for
# future study.
#
# The read email is then put into the Archive folder.
#

use Modern::Perl;
use FindBin qw($Bin);
use Data::Dumper;
use DateTime;
use List::Util qw(min max);
use YAML::Any;

use lib "$Bin/../lib";
use WWW::LacunaExpanse::API;
use WWW::LacunaExpanse::DB;
use WWW::LacunaExpanse::API::DateTime;

# Load configurations

my $config_mysql    = YAML::Any::LoadFile("$Bin/../mysql.yml");
my $config_account  = YAML::Any::LoadFile("$Bin/../myaccount.yml");

my $mysql_schema = WWW::LacunaExpanse::DB->connect(
    $config_mysql->{dsn},
    $config_mysql->{username},
    $config_mysql->{password},
    {AutoCommit => 1, PrintError => 1},
);

my $api = WWW::LacunaExpanse::API->new({
    uri         => $config_account->{uri},
    username    => $config_account->{username},
    password    => $config_account->{password},
});

# Read all emails, print the subjects

my $inbox       = $api->inbox;
my $my_empire   = $api->my_empire;

print "EMPIRE ID=".$my_empire->id."\n";

my $excavator_messages = {
    'Glyph Discovered!'         => 0,
    'Resources Discovered!'     => 0,
    'Excavator Found Nothing'   => 0,
    'Excavator Uncovered Plan'  => 0,
    'Ship Shot Down'            => 0,
};

print "inbox = $inbox\n";

my @archive_messages;

$inbox->reset_message;
MESSAGE:
while (my $message = $inbox->next_message) {
    # Look only for messages from me, to me
    if ($message->from_id == $my_empire->id && $message->to_id == $my_empire->id) {
        if (defined $excavator_messages->{$message->subject}) {
            print $message->date." ".$message->subject."\n";
            $excavator_messages->{$message->subject}++;
#            print $message->body."\n";

            my ($starmap) = $message->body
                =~ m/\{(Starmap[^\}]*)\}/;

            my ($planet) = $message->body
                =~ m/\{(Planet[^\}]*)/;
            my ($planet_id, $planet_name) = $planet =~ m/Planet (\d*) (.*)/;

            my ($quantity, $resource) = $message->body
                =~ m/it did find (\d*)\W(\w*)/;
            my ($glyph) = $message->body
                =~ m/entirely of (\w*)/;
            my ($level, $plan)  = $message->body
                =~ m/a level (\d*)\s(.*?)\./;

            $starmap        = $starmap      || '';
            $quantity       = $quantity     || '';
            $resource       = $resource     || '';
            $glyph          = $glyph        || '';
            $plan           = $plan         || '';
            $level          = $level        || '';

#            my $body_db;
            my $body_name;
            my $body_id;

            # Get the ID of the body
            if ($starmap) {
                my ($star_x, $star_y, $body) = $starmap =~ m/(-?\d+)\s(-?\d+)\s(.*)/;
                $body_name = $body;
#                print "Star [$star_x][$star_y] body [$body]\n";
                # Quicker to search the database rather than an API call
                my ($body_db) = $mysql_schema->resultset('Body')->search({name => $body});
                if ($body_db) {
                    $body_id = $body_db->id;
                }
                else {
#                    print "ERROR: Cannot find ($body) in the database\n";
                }
            }

            my $save_data = 0;
            my %resource_has;

            if ($planet && ! $starmap) {
                # Found by the archaeology ministry itself
                %resource_has = (
                    resource_genre  => 'glyph',
                    resource_type   => $glyph,
                    resource_qty    => 1,
                );
                # make the body the colony itself
                $body_name  = $planet_name;
                $body_id    = $planet_id;
                $save_data = 1;
            }
            elsif ($message->subject eq 'Ship Shot Down') {
                %resource_has = (
                    resource_genre  => 'ship_shot_down',
                    resource_type   => '',
                    resource_qty    => '',
                );
                $save_data = 1;
            }
            elsif (! $resource && ! $glyph && ! $plan) {
                # Found nothing
                %resource_has = (
                    resource_genre  => 'nothing',
                    resource_type   => '',
                    resource_qty    => '',
                );
                $save_data = 1;
            }
            elsif ($quantity && $resource) {
                # Found resource
                %resource_has = (
                    resource_genre  => 'resource',
                    resource_type   => $resource,
                    resource_qty    => $quantity,
                );
                $save_data = 1;
            }
            elsif ($plan) {
                # Found plan
                %resource_has = (
                    resource_genre  => 'plan',
                    resource_type   => $plan,
                    resource_qty    => $level,
                );
                $save_data = 1;
            }
            elsif ($glyph) {
                # Found glyph
                %resource_has = (
                    resource_genre  => 'glyph',
                    resource_type   => $glyph,
                    resource_qty    => 1,
                );
                $save_data = 1;
            }

            if ($save_data) {

                eval {
                    $mysql_schema->resultset('Excavation')->create({
                        server_id       => 1,
                        empire_id       => $my_empire->id,
                        body_id         => $body_id,
                        body_name       => $body_name,
                        on_date         => WWW::LacunaExpanse::API::DateTime->from_lacuna_email_string_mysql($message->date),
                        colony_id       => $planet_id,
                        resource_genre  => $resource_has{resource_genre},
                        resource_type   => $resource_has{resource_type},
                        resource_qty    => $resource_has{resource_qty},
                    });
                };
                if (my $e = $@) {
                    if ($e =~ m/Duplicate entry/) {
                        # If it is a duplicate message, it is already in the database so we can safely archive it
                        push @archive_messages, $message->id;
                    }
                    else {
                        print "ERROR: $@\n";
                    }
                }
                else {
                    push @archive_messages, $message->id;
                }
            }

#            print "Starmap [$starmap] planet [$planet] quantity [$quantity] resource [$resource] glyph [$glyph] plan [$plan] \n";

        }
        else {
#            print $message->date." ??? ".$message->subject."\n";
               push @archive_messages, $message->id;
        }
    }
}

$inbox->archive_messages(\@archive_messages);

for my $key (keys %$excavator_messages) {
    print $excavator_messages->{$key}, "\t $key\n";
}



1;
