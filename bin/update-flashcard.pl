#!/usr/bin/env -S perl -CA -Ilocal/lib/perl5

use strict;
use warnings;

use feature qw(say);
use lib 'lib';

binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN,  ':encoding(UTF-8)';

use Data::Dumper;
use Getopt::Long qw(GetOptionsFromArray);
use Term::ANSIColor qw(colored);

use Teochew;
use Teochew::Edit;
use Teochew::Utils qw(split_out_parens);
use Input qw(confirm input_from_prompt);

my $db = Teochew::Edit->new;

# First argument should be the English word
my $input = shift @ARGV;

die colored("Must provide an English word!", "red") . "\n"
    unless defined $input;

# Let's see what the user wants to update
my ($category, $alt_chinese, $category_sort);
GetOptions(
    "category=s"    => \$category,
    "alt-chinese=s" => \$alt_chinese,
    "category-sort" => \$category_sort,
);

# XXX There's probably an easier way of handling this
unless ($category || $alt_chinese || $category_sort) {
    say "Must provide one of these options:";
    say "\t--category";
    say "\t--alt-chinese";
    say "\t--category-sort";
    exit;
}

# Gather up the relevant information from the database for this translation
my %translation = $db->choose_translation_from_english($input);
my $english     = $translation{english};
my $teochew     = $translation{teochew};

my %update_english_params;

if ($category) {
    # First check if category exists already (you can only add new categories
    # manually, using sql, for now)
    my %categories = map { $_->{name} => $_->{id} } Teochew::categories;

    my $new_category_id = $categories{$category};
    die "Category '$category' doesn't exist!" unless $new_category_id;

    say "Changing category from $english->{category_name} to $category";
    if (confirm()) {
        $update_english_params{category_id} = $new_category_id;
        $english->{category_id} = $new_category_id;
    }

    $category_sort = 1;
}

# Sorta copy pasted from the insert-flashcards script
if ($category_sort) {
    my @words_by_sort =
        Teochew::category_words_by_sort_order($english->{category_id});
    for (@words_by_sort) {
        $_->{sort} //= '';
        say "$_->{sort}: " . substr($_->{words}, 0, 50);
    }
    my $sort = input_from_prompt("Sort order:");
    say "Changing sort order of english word to $sort";
    if (confirm()) {
        $update_english_params{sort} = $sort;
    }
}

if (%update_english_params) {
    $db->update_english($english->{id}, %update_english_params);
    say colored("Updated english word!", "green");
}

if ($alt_chinese) {

    # First check and see if these Chinese characters exist in the database
    $db->ensure_chinese_is_in_database(
        chinese => $alt_chinese,
        pengim  => $teochew->{pengim},
    );

    say "Adding $alt_chinese as an alternate for $teochew->{chinese}";
    if (confirm()) {
        $db->insert_alt_chinese(
            teochew_id => $teochew->{teochew_id},
            chinese    => $alt_chinese
        );
        say colored("Added $alt_chinese as an alternate!", "green");
    }
}
