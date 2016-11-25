package opsian;

use strict;
use warnings;
use vars qw($VERSION);
use WWW::Mechanize;
use Data::Dumper;

$VERSION = "0.1";

# constructor
sub new
{
    my $class = shift;
    my $server = shift;
    my $username = shift;
    my $password = shift;
    my $self = {};
    $self->{server} = $server;
    $self->{username} = $username;
    $self->{password} = $password;
    $self->{villages} = {};
    $self->{map} = {};
    $self->{mech} = new WWW::Mechanize();
    $self->{mech}->agent_alias( 'Windows IE 6' );
    bless $self, $class;
    return $self;
}

sub login
{
    my $self = shift;
    my $mech = $self->{mech};
    $mech->get($self->{server}."login.php");
    my $form = $mech->form_number(1);
    my $fusername = ($form->inputs)[2]->name;
    my $fpassword= ($form->inputs)[3]->name;
    $mech->field($fusername => $self->{username});
    $mech->field($fpassword => $self->{password});
    sleep 2;
    $mech->submit();    
}

# refresh tr data
sub getVillageData
{
    my $self = shift;
    $self->login();
    my $mech = $self->{mech};
    # get all villages
    foreach my $link ($mech->find_all_links(url_regex => qr/newdid=/i))
    {
        $link->url() =~ /newdid=(.*)/;
        $self->{villages}->{$1}->{name} = $link->text();
    }
    # get village data
    foreach my $did (keys %{$self->{villages}})
    {
        # res fields
        $mech->get($self->{server}."dorf1.php?newdid=$did");
        for(my $i = 1; $i <= 18; $i++)
        {
            $mech->content() =~ /area href="build.php\?id=$i".*?title="(.*?)"/;
            $self->{villages}->{$did}->{$i} = $1;
        }
        # buildings
        $mech->get($self->{server}."dorf2.php?newdid=$did");
        for(my $i = 19; $i <= 40; $i++)
        {
            $mech->content() =~ /area href="build.php\?id=$i".*?title="(.*?)"/;
            $self->{villages}->{$did}->{$i} = $1;
        }
    }
    return;
}

sub parseMapSQL
{
    my $self = shift;
    my $mech = $self->{mech};
    my $map = $self->{map};
    $mech->get($self->{server}."map.sql");
    print "parsing map.sql...\n";
    my $content = $mech->content();
    while($content =~ s/INSERT INTO \`x_world\` VALUES \((.*),(.*),(.*),(.*),(.*),'(.*)',(.*),'(.*)',(.*),'(.*)',(.*)\);\n//)
    {
        my($id, $x, $y, $tid, $vid, $village, $uid, $player, $aid, $alliance, $population) =
            ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
        $self->{map}->{$id}->{tid} = $tid;
        $self->{map}->{$id}->{vid} = $vid;
        $self->{map}->{$id}->{vil} = $village;
        $self->{map}->{$id}->{uid} = $uid;
        $self->{map}->{$id}->{pl} = $player;
        $self->{map}->{$id}->{aid} = $aid;
        $self->{map}->{$id}->{al} = $alliance;
        $self->{map}->{$id}->{pop} = $population;
    }
}

sub xy2id
{
    my $self = shift;
    my $x = shift;
    my $y = shift;
    my $id = (400 - $y) * 801 + $x + 401;
    return $id;
}

sub id2xy
{
    my $self = shift;
    my $id = shift;
    my $y = int($id / 801);
    my $x = $id - $y * 801 - 401;
    $y = 400 - $y;
    return ($x, $y);
}

sub s5raidinit
{
    my $self = shift;
    
	# village 1
    my $i = 0;
    my $j = 0;
       
	# add farms here
    $self->{farms1}[$i++] = "344881"; # x|y add description here
    $self->{farms1}[$i++] = "344085"; # x|y add description here
    
	# paladin mode
    if($self->{palamode}) {
		# add farms here
		$self->{farms1}[$i++] = "347085"; # x|y add description here
    }
    
    for(my $k = 0; $k < $i; $k++) {
        $self->{num1}[$k] = 5;
    }
    
    $self->{farmcount1} = $i;
    $self->{wantres1} = 0;
    
    # village 2
    $i = 0;
    $j = 0;
    
    # add farms here
    $self->{farms2}[$i++] = "368954"; # x|y add description here

    for(my $k = 0; $k < $i; $k++) {
        $self->{num2}[$k] = 5;
    }
    
    $self->{farmcount2} = $i;    
    $self->{wantres2} = 0;
    
    $self->{resnr1} = 0;
    $self->{buildtroops1} = 0;
    $self->{research1} = 0;

    $self->{resnr2} = 0;
    $self->{buildtroops2} = 0;
    $self->{research2} = 0;

}

sub s5raid
{
    my $self = shift;
    my $dorfid = shift;
    my $dorfnr = shift;
    my $mech = $self->{mech};
    $mech->get($self->{server}."dorf1.php?newdid=$dorfid");
    my $content = $mech->content();
    my $r_wood;
    if($content =~ /<td id=l4 title=.*?>(.*?)\//) {
        $r_wood = $1;
    } else {
        print "logging in...\n";
        $self->login();
        return;
    }
    $content =~ /<td id=l3 title=.*?>(.*?)\//;
    my $r_clay = $1;
    $content =~ /<td id=l2 title=.*?>(.*?)\//;
    my $r_iron = $1;
    $content =~ /<td id=l1 title=.*?>(.*?)\//;
    my $r_wheat = $1;
    my $is_building = ($content =~ /<div class="f10 b">Building/);
    my $t_macemen = 0;
    my $t_axemen = 0;
    my $t_paladins = 0;
    if($content =~ /.*<td align="right">&nbsp;<b>(.*?)<\/b><\/td><td>Macemen/) {
        $t_macemen = $1;
    }
    if($content =~ /.*<td align="right">&nbsp;<b>(.*?)<\/b><\/td><td>Axemen/) {
        $t_axemen = $1;
    }
    if($content =~ /.*<td align="right">&nbsp;<b>(.*?)<\/b><\/td><td>Paladins/) {
        $t_paladins = $1;
    }
    # raiding
    my $dorf;
    my($tx,$ty);
    if($dorfnr==1) {
        $dorf = "Foo          ";
        ($tx,$ty)=(56,-35);
        #$t_paladins = $t_paladins-100;
        if($t_paladins<0) {
            $t_paladins=0;
        }
    }
    if($dorfnr==2) {
        $dorf = "Bar          ";
        ($tx,$ty)=(96,-59);
        $t_paladins = 0;
    }
	# add additional villages here
    print "[$dorf] ".POSIX::strftime("%H:%M",localtime())." - ";
    if($t_macemen*60 >= $self->{"wantres$dorfnr"} || ($t_paladins*110 >= $self->{"wantres$dorfnr"} && $t_paladins>2)) {
        if($self->{"farmcount$dorfnr"} > 0) {
            $self->{"curfarm$dorfnr"}++;
            if($self->{"curfarm$dorfnr"} >= $self->{"farmcount$dorfnr"}) {
                $self->{"curfarm$dorfnr"} = 0;
            }
            my $farm = $self->{"farms$dorfnr"}[$self->{"curfarm$dorfnr"}];
            my($x, $y) = $self->id2xy($farm);
            my $dist = int(sqrt(($tx-$x)*($tx-$x)+($ty-$y)*($ty-$y)));
            $mech->get($self->{server}."karte.php?xp=$x&yp=$y");
            $mech->content() =~ /(karte.php\?d=$farm&c=.*?)"/;
            $mech->get($self->{server}.$1);
            if($mech->content() =~ /Unoccupied valley/) {
                $self->{"num$dorfnr"}[$self->{"curfarm$dorfnr"}] = 0;
                print "#".$self->{"curfarm$dorfnr"}." $farm ($x|$y) got deleted!!\n";
                return;
            }
            $mech->content() =~ /(berichte.php\?id=.*?)"/;
            $mech->get($self->{server}.$1);
            $content = $mech->content();
            $content =~ s/\n//g;
            my $res = 0;
            if($content =~ /<img class="res" src=".*?">(\d+) .*?<img class="res" src=".*?">(\d+) .*?<img class="res" src=".*?">(\d+) .*?<img class="res" src=".*?">(\d+)</) {
                $res = $1+$2+$3+$4;
            }
            my $maces = 0;
            my $palas = 0;
            if($content =~ /<td>Troops<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td>/) {
                $maces = $1;
                $palas = $5;
            }
            my $casual = 0;
            if($content =~ /<td>Casualties<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td><td(?: class="c")?>(\d+) ?<\/td>/) {
                $casual = $1+$2+$3+$4+$5;
            }
            if($casual > 0) {
                $self->{"num$dorfnr"}[$self->{"curfarm$dorfnr"}] = 0;
                print "not raiding $farm ($x|$y) (last: $casual casualties)\n";
            }
            my $attackmode = 4;
            if($content =~ /<b>Gauls<\/b>/) {
                $attackmode = 3;
            }
            if($self->{"num$dorfnr"}[$self->{"curfarm$dorfnr"}] > 0) {
                my $n_macemen = 0;
                my $n_paladins = 0;
                $self->{"wantres$dorfnr"} = 180;
                if($res >= 180) {
                    $self->{"wantres$dorfnr"} = 300;
                }
                if($res >= 300) {
                    $self->{"wantres$dorfnr"} = 600;
                }
                if($res >= 600) {
                    $self->{"wantres$dorfnr"} = 900;
                }
                #if($res >= 900) {
                #    $self->{"wantres$dorfnr"} = 1200;
                #}
                if($self->{"wantres$dorfnr"} < 300) {
                    $self->{"wantres$dorfnr"} = 300;
                }
                if($self->{"wantres$dorfnr"} < 600) {
                    $self->{"wantres$dorfnr"} = 600;
                }
                $self->{"wantres$dorfnr"} = 1800;
                #if($dorfnr<3) {
                #    $self->{"wantres$dorfnr"} = 1200;
                #}
                if($t_paladins*110>=$self->{"wantres$dorfnr"}) {
                    $n_paladins = POSIX::ceil($self->{"wantres$dorfnr"}/110);
                } else {
                    if($t_macemen*60>=$self->{"wantres$dorfnr"}) {
                        $n_macemen = POSIX::ceil($self->{"wantres$dorfnr"}/60);
                    }
                }
                if($n_macemen>0 || $n_paladins>0) {
                    sleep 2;
                    if($attackmode==4) {
                        print "raid";
                    } else {
                        print "attk";
                    }
                    print " ($x|$y) d$dist (#".$self->{"curfarm$dorfnr"}."), ".($n_macemen>0?"$n_macemen mace ":"$n_paladins pala ")."(last: $maces mace $palas pal, $res res)\n";
                    $mech->get($self->{server}."a2b.php?newdid=$dorfid&z=$farm");
                    $content = $mech->content();
                    $mech->form_name("snd");
                    if($n_macemen>0) {
                        $mech->set_fields('t1'=>"".$n_macemen, 'c'=>"$attackmode");
                    } else {
                        $mech->set_fields('t5'=>"".$n_paladins, 'c'=>"$attackmode");                        
                    }
                    $mech->submit_form();
                    $mech->form_number(1);
                    sleep 2;
                    $mech->submit_form();
                    $self->{"wantres$dorfnr"} = 0;
                } else {
                    print "#".$self->{"curfarm$dorfnr"}." ($x|$y) waiting troops for ".($self->{"wantres$dorfnr"})." res, last $res res\n";
                    $self->{"curfarm$dorfnr"}--;
                }
            }
        }
    } else {
        print "#".($self->{"curfarm$dorfnr"}+1)." ".$t_macemen."M - $r_wood/$r_clay/$r_iron/$r_wheat\n";
    }
    # building troops
    if($self->{"buildtroops$dorfnr"} > 0) {
    if($r_wood >= 95 && $r_clay >= 75 && $r_iron >= 40 && $r_wheat >= 80) {
        print "building 1 maceman\n";
        $mech->get($self->{server}."build.php?id=25");
        $mech->form_number(1);
        $mech->set_fields('t1'=>"1");
        $mech->submit_form();
        $self->{"buildtroops$dorfnr"}--;
    }
    }
    # building res
    if($self->{"resnr$dorfnr"} == 15 && !$is_building) {
    if($r_wood >= 545 && $r_clay >= 700 && $r_iron >= 545 && $r_wheat >= 155) {
        print "building wheat lv5\n";
        $self->{"resnr$dorfnr"} = 0;
        $mech->get($self->{server}."dorf1.php?a=15&c=b57");
        $self->{"buildtroops$dorfnr"} = 3;
    }
    }
    if($self->{"resnr$dorfnr"} == 13 && !$is_building) {
    if($r_wood >= 545 && $r_clay >= 700 && $r_iron >= 545 && $r_wheat >= 155) {
        print "building wheat lv5\n";
        $self->{"resnr$dorfnr"} = 15;
        $mech->get($self->{server}."dorf1.php?a=13&c=b57");
        #$self->{"buildtroops$dorfnr"} = 50;
    }
    }
    if($self->{"resnr$dorfnr"} == 12 && !$is_building) {
    if($r_wood >= 545 && $r_clay >= 700 && $r_iron >= 545 && $r_wheat >= 155) {
        print "building wheat lv5\n";
        $self->{"resnr$dorfnr"} = 13;
        $mech->get($self->{server}."dorf1.php?a=12&c=b57");
        #$self->{buildtroops} = 1;
    }
    }
    # research
    if($self->{"research$dorfnr"}) {
    if($r_wood >= 970 && $r_clay >= 380 && $r_iron >= 880 && $r_wheat >= 400) {
        print "researching spearmen\n";
        $mech->get($self->{server}."build.php?id=22&a=".$self->{"research$dorfnr"});
        $self->{"research$dorfnr"} = 0;
    }
    }
    # residence
    if(0) {
    $mech->get($self->{server}."build.php?id=32");
    if($mech->content() =~ /<a href="(dorf2.php\?a=..&c=.*?)">Upgrade to level (8|9|10)/) {
        sleep 2;
        print "upgrading residence to level $2\n";
        $mech->get($self->{server}.$1);
    }
    }
}

sub findOases
{
    my $self = shift;
    my $x0 = shift;
    my $y0 = shift;
    my $x1 = shift;
    my $y1 = shift;
    $self->login();
    my $mech = $self->{mech};
    my $map = $self->{map};
    for(my $xp = $x0; $xp < $x1 && 0; $xp += 7)
    {
        for(my $yp = $y0; $yp < $y1; $yp += 7)
        {
            print "scanning ($xp|$yp)\n";
            $mech->get($self->{server}."karte.php?xp=$xp&yp=$yp");
            my $content = $mech->content();
            $content =~ s/\n//g;
            $content =~ /div class="mdiv"(.*)<\/div/m;
            my $mdiv = $1;
            my $found = 0;
            while($mdiv =~ s/img (?:id=".*?" )?class="mt(..?)"  ?src="img\/un\/m\/o(.*?).gif"//)
            {
                my($x, $y) = ($xp - 3 + ($1 - 1) % 7, $yp + 3 - int(($1 - 1) / 7));
                my $oasis = $2;
                my $id = $self->xy2id($x, $y);
                $map->{$id}->{tid} = 4;
                $map->{$id}->{vil} = "o$oasis";
                for(my $xd = -3; $xd <= 3; $xd++)
                {
                    for(my $yd = -3; $yd <= 3; $yd++)
                    {
                        my $id = $self->xy2id($x + $xd, $y + $yd);
                        $map->{$id}->{bla} = 0;
                        $map->{$id}->{lb}++ if $oasis eq "1" || $oasis eq "2" || $oasis eq "3";
                        $map->{$id}->{cb}++ if $oasis eq "4" || $oasis eq "5" || $oasis eq "6";
                        $map->{$id}->{ib}++ if $oasis eq "7" || $oasis eq "8" || $oasis eq "9";
                        $map->{$id}->{wb1}++ if $oasis eq "10" || $oasis eq "11" || $oasis eq "3" || $oasis eq "6" || $oasis eq "9";
                        $map->{$id}->{wb2}++ if $oasis eq "12";
                    }
                }
            }
        }
    }
    my $found = "";
    #foreach my $id (sort keys %$map)
    for(my $xp = $x0; $xp < $x1; $xp++)
    {
    for(my $yp = $y0; $yp < $y1; $yp++)
    {
        #my $wb1 = $map->{$id}->{wb1} ? $map->{$id}->{wb1} : 0;
        #my $wb2 = $map->{$id}->{wb2} ? $map->{$id}->{wb2} : 0;
        #if($wb2 == 3 || ($wb2 == 2 && $wb1 >= 1))
        #if(($wb2 >= 2 || ($wb2 == 1 && $wb1 >= 2)))
        #if($wb2 >=0 || $wb1 >=0)
        #{
            #my($x, $y) = $self->id2xy($id);
            #sleep 1;
            my $id = $self->xy2id($xp,$yp);
            print "checking $id ($xp|$yp)...\n";
            $mech->get($self->{server}."karte.php?xp=$xp&yp=$yp");
            $mech->content() =~ /"karte.php\?d=$id(?:&|&amp;)c=(.*?)"/;
            $mech->get($self->{server}."karte.php?d=$id&c=$1");
            if($mech->content() =~ /<td class="s7 b">(9|15)<\/td><td>(Wheat Fields|Getreidefarmen)<\/td>/)
            {
                $found .= "($xp|$yp)\n";
                print "---------------------------------\n";
            }
        #}
    }
    }
    print "---------------------------------\n";
    print "15CROPPERS:\n";
    print $found;
}

sub saveData
{
    my $self = shift;
    my $filename = shift;
    my $fh;
    open $fh, ">", $filename or die("could not open file: $filename");
    my $map = $self->{map};
    $Data::Dumper::Indent = 0;
    print "saving data to $filename...\n";
    print $fh Data::Dumper->Dump([$map], ["map"]);
    close $fh;
}

sub loadData
{
    my $self = shift;
    my $filename = shift;
    my $fh;
    open $fh, $filename or die ("ould not open file: $filename");
    local $/ = undef;
    print "loading data from $filename...\n";
    my $content = <$fh>;
    close $fh;
    $content =~ s/^\$map =/\$self->{map} =/;
    eval $content;
}

1;
__END__
