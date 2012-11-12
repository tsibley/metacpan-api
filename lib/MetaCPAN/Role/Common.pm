package MetaCPAN::Role::Common;

use Moose::Role;
use ElasticSearch;
use Log::Contextual qw( set_logger :log :dlog );
use Log::Log4perl ':easy';
use MetaCPAN::Types qw(:all);
use ElasticSearchX::Model::Document::Types qw(:all);
use MooseX::Types::Path::Class qw(:all);
use FindBin;
use MetaCPAN::Model;
use PerlIO::gzip;

has 'cpan' => (
    is         => 'rw',
    isa        => Dir,
    lazy_build => 1,
    coerce     => 1,
    documentation =>
        'Location of a local CPAN mirror, looks for $ENV{MINICPAN} and ~/CPAN'
);

has perms => (
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    traits     => ['NoGetopt']
);

has release_pattern => (
    is              => 'ro',
    isa             => 'RegexpRef',
    default         => sub { qr/\.(tgz|tbz|tar[\._-]gz|tar\.bz2|tar\.Z|zip|7z)$/ },
    documentation   => "regexp matching release tarball extensions",
    traits          => ['NoGetopt'],
);

has level => (
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    trigger       => \&set_level,
    documentation => 'Log level'
);

has es => (
    isa           => ES,
    is            => 'ro',
    required      => 1,
    coerce        => 1,
    documentation => 'ElasticSearch http connection string'
);

has model => ( lazy_build => 1, is => 'ro', traits => ['NoGetopt'] );

has index => (
    reader        => '_index',
    is            => 'ro',
    isa           => 'Str',
    default       => 'cpan',
    documentation => 'Index to use, defaults to "cpan"'
);

has port => (
    isa           => 'Int',
    is            => 'ro',
    required      => 1,
    documentation => 'Port for the proxy, defaults to 5000'
);

has logger => (
    is        => 'ro',
    required  => 1,
    isa       => Logger,
    coerce    => 1,
    predicate => 'has_logger',
    traits    => ['NoGetopt']
);

has home => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    default => "$FindBin::RealBin/..",
);

sub index {
    my $self = shift;
    return $self->model->index( $self->_index );
}

sub set_level {
    my $self = shift;
    $self->logger->level(
        Log::Log4perl::Level::to_priority( uc( $self->level ) ) );
}

sub _build_model {
    my $self = shift;
    return MetaCPAN::Model->new( es => $self->es );
}

# NOT A MOOSE BUILDER
sub _build_logger {
    my ($config) = @_;
    my $log = Log::Log4perl->get_logger( $ARGV[0] );
    foreach my $c (@$config) {
        my $layout = Log::Log4perl::Layout::PatternLayout->new( $c->{layout}
                || "%d %p{1} %c: %m{chomp}%n" );
        my $app = Log::Log4perl::Appender->new( $c->{class}, %$c );
        $app->layout($layout);
        $log->add_appender($app);
    }
    return $log;
}

sub file2mod {

    my $self = shift;
    my $name = shift;

    $name =~ s{\Alib\/}{};
    $name =~ s{\.(pod|pm)\z}{};
    $name =~ s{\/}{::}gxms;

    return $name;
}

sub _build_cpan {
    my $self = shift;
    my @dirs
        = ( "$ENV{'HOME'}/CPAN", "$ENV{'HOME'}/minicpan", $ENV{'MINICPAN'} );
    foreach my $dir ( grep {defined} @dirs ) {
        return $dir if -d $dir;
    }
    die
        "Couldn't find a local cpan mirror. Please specify --cpan or set MINICPAN";

}

sub _build_perms {
    my $self = shift;
    my $file = $self->cpan->file(qw(modules 06perms.txt));
    my %authors;
    if ( -e $file ) {
        log_debug { "parsing ", $file };
        my $fh = $file->openr;
        while ( my $line = <$fh> ) {
            my ( $module, $author, $type ) = split( /,/, $line );
            next unless ($type);
            $authors{$module} ||= [];
            push( @{ $authors{$module} }, $author );
        }
        close $fh;
    }
    else {
        log_warn {"$file could not be found."};
    }

    my $packages = $self->cpan->file(qw(modules 02packages.details.txt.gz));
    if ( -e $packages ) {
        log_debug { "parsing ", $packages };
        open my $fh, "<:gzip", $packages;
        while ( my $line = <$fh> ) {
            if ( $line =~ /^(.+?)\s+.+?\s+\S\/\S+\/(\S+)\// ) {
                $authors{$1} ||= [];
                push( @{ $authors{$1} }, $2 );
            }
        }
        close $fh;
    }
    return \%authors;
}

sub remote {
    shift->es->transport->default_servers->[0];
}

sub run { }
before run => sub {
    my $self = shift;
    unless ($MetaCPAN::Role::Common::log) {
        $MetaCPAN::Role::Common::log = $self->logger;
        set_logger $self->logger;
    }
    Dlog_debug {"Connected to $_"} $self->remote;
};

1;

=pod

=head1 SYNOPSIS

Roles which should be available to all modules

=cut
