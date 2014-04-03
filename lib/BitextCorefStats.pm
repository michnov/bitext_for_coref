package Treex::Block::My::BitextCorefStats;

use Moose;
use Treex::Core::Common;
use Readonly;

extends 'Treex::Block::Write::BaseTextWriter';

use constant {
    CS_SRC_FILTER => {language => 'cs', selector => 'src'},
    EN_SRC_FILTER => {language => 'en', selector => 'src'},
    CS_REF_FILTER => {language => 'cs', selector => 'ref'},
    EN_REF_FILTER => {language => 'en', selector => 'ref'},
};

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
    my ($self, $name, $address, $result, $errors) = @_;

    if (!defined $result) {
        $result = "ERR:" . (join ",", @$errors);
    }
    
    print {$self->_file_handle} "$name\t";
    print {$self->_file_handle} $result;
    print {$self->_file_handle} "\t" . $address;
    print {$self->_file_handle} "\n";
}

1;
