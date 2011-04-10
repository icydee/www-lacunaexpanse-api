#!/home/icydee/localperl/bin/perl

# Script to read emails and put them into the database
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

my $schema = WWW::LacunaExpanse::DB->connect(
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

my $excavator_messages = {
    'Glyph Discovered!'         => 0,
    'Resources Discovered!'     => 0,
    'Excavator Found Nothing'   => 0,
    'Excavator Uncovered Plan'  => 0,
    'Ship Shot Down'            => 0,
};

my @archive_messages;
my $message_count = 0;

$inbox->reset_message;
my @all_messages = $inbox->all_messages;

MESSAGE:
# Read all messages, oldest first
for my $message (reverse @all_messages) {
    print "subject      : ".$message->subject       ."\n";
    print "date         : ".$message->date          ."\n";

    # Do we already have the message?
    my ($db_message) = $schema->resultset('Message')->search({
        server_id       => 1,
        empire_id       => $my_empire->id,
        message_id      => $message->id,
    });
    if (! $db_message ) {
        # Not already saved, so save it.
        eval {
           my $db_message = $schema->resultset('Message')->create({
               server_id       => 1,
               empire_id       => $my_empire->id,
               message_id      => $message->id,
               subject         => $message->subject,
               on_date         => $message->date,
               sender          => $message->from,
               sender_id       => $message->from_id,
               recipient       => $message->to,
               recipient_id    => $message->to_id,
               has_read        => $message->has_read,
               has_replied     => $message->has_replied,
               has_archived    => $message->has_archived,
               in_reply_to     => $message->in_reply_to,
               body_preview    => $message->body_preview,
               body            => $message->body,
           });
        };
        if ($@) {
            my $e = $@;
            print "### $e ###\n";
            if ($e =~ m/Duplicate entry/) {
                # then we have already stored it, don't worry
            }
            else {
                die "Cannot save record. $e";
            }
        }
    }
    # If it is one of the excavator messages, then archive it
    if ($message->from_id == $my_empire->id && $message->to_id == $my_empire->id) {
        if (defined $excavator_messages->{$message->subject}) {
            push @archive_messages, $message->id;
        }
    }
    if (++$message_count == 20) {
        $message_count = 0;
        print "############ ARCHIVE MESSAGES ###############\n";
        $inbox->archive_messages(\@archive_messages);
        undef @archive_messages;
    }
}

# archive any remaining messages
if (@archive_messages) {
    print "############ ARCHIVE MESSAGES ###############\n";
    $inbox->archive_messages(\@archive_messages);
}

1;
