#!/usr/bin/env perl6

subset File of Str where *.IO.f;

sub MAIN (
    File :$in!,
    Str  :$out="",
    Str  :$alias-file=""
) {
    my %alias;
    if $alias-file && $alias-file.IO.f {
        my $fh  = open $alias-file;
        my @hdr = $fh.get.split(/\t/); # name, alias -- not used
        %alias  = $fh.lines.map(*.split(/\t/)).flat;
    }

    sub clean-file-name($file) {
        my $basename = $file.IO.basename;
        $basename   ~~ s/'.' msh $//;
        $basename   ~~ s/'.' gz $//;
        $basename   ~~ s/'.' fn?a(st<[aq]>)? $//;
        %alias{$basename} || $basename;
    }

    my $out-file = $out || do {
        my $ext      = $in.IO.extension;
        my $basename = $in.IO.basename.subst(/'.' $ext $/, '');
        $*SPEC.catfile($in.IO.dirname, $basename ~ '.2.' ~ $ext);
    };

    my $in-fh  = open $in, :r;
    my $out-fh = open $out-file, :w;

    for $in-fh.lines.kv -> $i, $line {
        my @flds = $line.split(/\t/);

        if $i == 0 {
            my $query = @flds.shift; # literal "#query", not needed
            my @files = @flds.map(&clean-file-name);
            $out-fh.put(join("\t", flat "", @files));
        }
        else {
            my $file = clean-file-name(@flds.shift);
            next if all(@flds) == 1;
            $out-fh.put(join "\t", flat $file, @flds);
        }
    }

    $in-fh.close;
    $out-fh.close;

    put "Done, see '$out-file'";
}
