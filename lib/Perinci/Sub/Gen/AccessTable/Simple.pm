package Perinci::Sub::Gen::AccessTable::Simple;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(gen_read_table_func);

our %SPEC;

sub _gen_meta {
    my ($parent_args) = @_;

    my $func_meta = {
        v => 1.1,
        summary => $parent_args->{summary} // "REPLACE ME",
        description => $parent_args->{description} // "REPLACE ME",
        args => {},
        'x.dynamic_generator_modules' => [__PACKAGE__],
    };

    my $func_args = $func_meta->{args};

    for my $f (@{ $parent_args->{filter_fields} // [] }) {
        $func_args->{$f} = {
            schema => 'str*',
            summary => "Filter by value of $f",
            tags   => ['category:filtering'],
        };
    }

    [200, "OK", $func_meta];
}

sub _gen_func {
    my ($parent_args) = @_;

    my $func = sub {
        my %args = @_;

        my $field_names   = $parent_args->{field_names};
        my $filter_fields = $parent_args->{filter_fields} // [];
        my @rows;
      ROW:
        for my $row0 (@{ $parent_args->{table_data} }) {
            my $row = {};
            for my $i (0..$#{$field_names}) {
                $row->{$field_names->[$i]} = $row0->[$i];
            }
          FILTER:
            for my $f (@$filter_fields) {
                if (defined($args{$f}) && (
                    !defined($row->{$f}) || $row->{$f} ne $args{$f})) {
                    next ROW;
                }
            }
            push @rows, $row;
        }

        [200, "OK", \@rows, {'table.fields' => $field_names}];
    }; # func;

    [200, "OK", $func];
}

$SPEC{gen_read_table_func} = {
    v => 1.1,
    summary => 'Generate function (and its metadata) to read table data',
    description => <<'_',

The generated function acts like a simple single table SQL SELECT query,
featuring filtering by zero or more fields (exact matching). For more features,
see the <pm:Perinci::Sub::Gen::AccessTable> variant. This routine is a
simplified version.

The resulting function returns an array of hashrefs and accepts these arguments.

* Filter arguments

  They will be generated for each field specified in `filter_fields`.

_
    args => {
        %Perinci::Sub::Gen::common_args,
        table_data => {
            schema => ['array*', of => 'array*'],
            req => 1,
        },
        field_names => {
            schema => ['array*', of => 'str*'],
            req => 1,
        },
        filter_fields => {
            schema => ['array*', of => 'str*'],
        },
    }, # args
    result => {
        summary => 'A hash containing generated function, metadata',
        schema => 'hash*',
    },
};
sub gen_read_table_func {
    my %args = @_;

    # XXX schema
    my ($uqname, $package);
    my $fqname = $args{name};
    return [400, "Please specify name"] unless $fqname;
    my @caller = caller();
    if ($fqname =~ /(.+)::(.+)/) {
        $package = $1;
        $uqname  = $2;
    } else {
        $package = $args{package} // $caller[0];
        $uqname  = $fqname;
        $fqname  = "$package\::$uqname";
    }
    my $table_data = $args{table_data}
        or return [400, "Please specify table_data"];
    #__is_aoa($table_data)
    #    or return [400, "Invalid table_data: must be AoA"];

    my $res;
    $res = _gen_meta(\%args);
    return err(500, "Can't generate meta", $res) unless $res->[0] == 200;
    my $func_meta = $res->[2];

    $res = _gen_func(\%args);
    return err(500, "Can't generate func", $res) unless $res->[0] == 200;
    my $func = $res->[2];

    if ($args{install} // 1) {
        no strict 'refs';
        no warnings;
        *{ $fqname } = $func;
        ${$package . "::SPEC"}{$uqname} = $func_meta;
    }

    [200, "OK", {meta=>$func_meta, code=>$func}];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

In list_countries.pl:

 #!perl
 use strict;
 use warnings;
 use Perinci::CmdLine;
 use Perinci::Sub::Gen::AccessTable::Simple qw(gen_read_table_func);

 our %SPEC;

 my $countries = [
     ['cn', 'China', 'Cina'],
     ['id', 'Indonesia', 'Indonesia'],
     ['sg', 'Singapore', 'Singapura'],
     ['us', 'United States of America', 'Amerika Serikat'],
 ];

 my $res = gen_read_table_func(
     name          => 'list_countries',
     summary       => 'func summary',     # optional
     description   => 'func description', # optional
     table_data    => $countries,
     field_names   => [qw/code en_name id_name/],
     filter_fields => ['code'],
 );
 die "Can't generate function: $res->[0] - $res->[1]" unless $res->[0] == 200;

 Perinci::CmdLine->new(url=>'/main/list_countries')->run;

Now you can do:

 # list all countries
 % list_countries.pl
 .--------------------------+------+-----------------.
 | en_name                  | code | id_name         |
 +--------------------------+------+-----------------+
 | China                    | cn   | Indonesia       |
 | Indonesia                | id   | Indonesia       |
 | Singapore                | sg   | Singapura       |
 | United States of America | us   | Amerika Serikat |
 '--------------------------+------+-----------------'

 # filter by code
 % list_countries.pl --code id
 .-----------+------+-----------.
 | en_name   | code | id_name   |
 +-----------+------+-----------+
 | Indonesia | id   | Indonesia |
 '-----------+------+-----------'

 # unknown code
 % list_countries.pl --code xx

 # output json
 % list_countries.pl --code id --json
 [200, "OK", [{"en_name":"Indonesia","code":"id","id_name":"Indonesia"}]


=head1 DESCRIPTION

This module is like L<Perinci::Sub::Gen::AccessTable>, but simpler. No table
spec is needed, only list of fields (C<field_names>). The function does not do
sorting or paging. Only the simplest filter (exact matching) is created.

Some other differences:

=over

=item * Table data must be AoAoS (array of array of scalars)

AoH or coderef not accepted.

=item * Function returns AoHoS, records are returned as HoS (hash of scalars)

=back


=head1 FAQ


=head1 SEE ALSO

L<Perinci::Sub::Gen::AccessTable>

=cut
