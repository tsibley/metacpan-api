package MetaCPAN::Script::Mapping;

use Moose;
with 'MooseX::Getopt';
use Log::Contextual qw( :log );
with 'MetaCPAN::Role::Common';

use MetaCPAN;
use MetaCPAN::Document::Author;
use MetaCPAN::Document::Release;
use MetaCPAN::Document::Distribution;
use MetaCPAN::Document::File;
use MetaCPAN::Document::Module;
use MetaCPAN::Document::Dependency;
use MetaCPAN::Document::Mirror;

sub run {
    shift->put_mappings(MetaCPAN->new->es);
}

sub put_mappings {
    my ($self, $es) = @_;
    # do not delete mappings, this will delete the data as well
    # ElasticSearch merges new mappings if possible
    for(qw(Author Release Distribution File Module Dependency Mirror)) {
        log_info { "Putting mapping for $_" };
        my $class = "MetaCPAN::Document::$_";
        $class->meta->put_mapping( $es );
    }

    return;

}

sub map_perlmongers {
    my ($self, $es) = @_;
    return $es->put_mapping(
        index      => ['cpan'],
        type       => 'perlmongers',
        properties => {
            city      => { type       => "string" },
            continent => { type       => "string" },
            email     => { properties => { type => { type => "string" } } },
            inception_date =>
                { format => "dateOptionalTime", type => "date" },
            latitude => { type => "object" },
            location => {
                properties => {
                    city      => { type => "string" },
                    continent => { type => "string" },
                    country   => { type => "string" },
                    latitude  => { type => "string" },
                    longitude => { type => "string" },
                    region    => { type => "object" },
                    state     => { type => "string" },
                },
            },
            longitude    => { type => "object" },
            mailing_list => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            name   => { type => "string" },
            pm_id  => { type => "string" },
            region => { type => "string" },
            state  => { type => "object" },
            status => { type => "string" },
            tsar   => {
                properties => {
                    email => {
                        properties => {
                            domain => { type => "string" },
                            type   => { type => "string" },
                            user   => { type => "string" },
                        },
                    },
                    name => { type => "string" },
                },
            },
            web => { type => "string" },
        },

    );

}



__PACKAGE__->meta->make_immutable;