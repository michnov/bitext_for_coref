package Treex::Block::My::AddRobustAlignment::CsRelpron;

use Moose;
use Treex::Tool::Align::Utils;
use Treex::Core::Common;

use Treex::Tool::Align::Robust::CS::RelPron;
use Treex::Tool::Coreference::NodeFilter::RelPron;

extends 'Treex::Block::My::AddRobustAlignment';

has '+_align_lang' => (default => 'en');
has '_align_zone' => (is => 'ro', isa => 'HashRef[Str]', builder => '_build_align_zone', lazy => 1);

sub _does_apply {
    my ($self, $tnode) = @_;
    return Treex::Tool::Coreference::NodeFilter::RelPron::is_relat($tnode);
}

sub _get_align_selectors {
    return [ 
        'self', 
        \&Treex::Tool::Align::Robust::CS::RelPron::access_via_alayer, 
        'eparents', 
        'siblings', 
        \&Treex::Tool::Align::Robust::CS::RelPron::select_via_self_siblings,
    ];
}

sub _get_align_filters {
    return [ 
        \&Treex::Tool::Align::Robust::CS::RelPron::filter_self,
        \&Treex::Tool::Align::Robust::CS::RelPron::filter_anodes,
        \&Treex::Tool::Align::Robust::CS::RelPron::filter_eparents,
        \&Treex::Tool::Align::Robust::CS::RelPron::filter_siblings,
        \&Treex::Tool::Align::Robust::CS::RelPron::filter_appos,
    ];
}

1;
