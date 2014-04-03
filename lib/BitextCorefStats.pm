package Treex::Block::My::BitextCorefStats;

use Moose;
use Treex::Core::Common;
use Readonly;

extends 'Treex::Block::Write::BaseTextWriter';

has align_selector => (is => 'ro', isa => 'Str', default => 'ref', required => 1);

Readonly::Hash my %CS_SRC_FILTER => (language => 'cs', selector => 'src');
Readonly::Hash my %EN_SRC_FILTER => (language => 'en', selector => 'src');
Readonly::Hash my %CS_REF_FILTER => (language => 'cs', selector => 'ref');
Readonly::Hash my %EN_REF_FILTER => (language => 'en', selector => 'ref');

sub unique {
    my ($a) = @_;
#        log_info "A: " . (join " ", map {$_->id} @$a);
    my @u = values %{ {map {$_ => $_} @$a} };
#        log_info "A: " . (join " ", map {$_->id} @u);
    return @u;
}

sub intersect {
    my ($a, $b) = @_;
#        log_info "A: " . (join " ", map {$_->id} @$a);
#        log_info "B: " . (join " ", map {$_->id} @$b);
    my %a_h = map {$_ => $_} @$a;
    my @inter = grep {defined $a_h{$_}} @$b;
#    if (scalar @inter) {
#        log_info "I: " . (join " ", map {$_->id} @inter);
#    }
    return @inter;
}

sub get_prf_counts {
    my ($true, $pred) = @_;
    my @inter = intersect($true, $pred);
    return (scalar @$true, scalar @$pred, scalar @inter);
}


sub print_info {
    my ($self, $tnode, $name, $method) = @_;

    my ($result, $errors) = $self->$method($tnode);

    if (!defined $result) {
        $result = "ERR:" . (join ",", @$errors);
    }
    
    print {$self->_file_handle} "$name\t";
    print {$self->_file_handle} $result;
    print {$self->_file_handle} "\t" . $tnode->get_address;
    print {$self->_file_handle} "\n";
}

sub filter_by_functor {
    my ($nodes, $functor, $errors) = @_;
    my ($functor_tnode) = grep {$_->functor eq $functor} @$nodes;
    if (!defined $functor_tnode) {
        push @$errors, "NO_FUNCTOR_TNODE";
        return;
    }
    return $functor_tnode;
}

sub eparents_of_aligned_siblings {
    my ($siblings, $errors) = @_;
    my ($epar, @epars) = unique([map {$_->get_eparents({or_topological => 1})} @$siblings]);
    if (@epars > 0) {
        push @$errors, "MANY_SIBLINGS_PARENTS";
        return;
    }
    return $epar;
}

1;
