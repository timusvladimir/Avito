#!/usr/bin/perl

use strict;
use MIME::Lite;
undef $/;

my $url=$ARGV[0];
my $mailer="ssmtp";
my $wget="wget";

if($url eq ""){
    print "Usage: avito.pl <https://www.avito.ru/...url>";
    exit;
}

my $filename=$url;
$filename=~s#[^A-Za-z0-9\.]#_#g;
$url=~m#(^.*?://.*?)/#;
my $site=$1;
print "site:".$site."\n";

sub sendsms {
    my $text=shift;
    my $msg = MIME::Lite->new(  From    => '*******@mail.ru',
                                To      => '********@gmail.com',
                                Subject => 'avitoshka',
                                Type    => 'text/plain; charset=UTF-8',
                                Data    => "$text" );
    $msg->send();
}

sub parse_page {
    open(MYFILE,"<".shift);
    my $text=<MYFILE>;
    close(MYFILE);
    my %page;
    

  while($text=~/<div class=\"item_table-wrapper\">.*?<a class="item-description-title-link"
 itemprop="url"
 href=\"(.*?)\".*?> <span itemprop=\"name"\>(\D*)span>.*?<span
 class=\"price \".*?>\n\s*(\w+\s\w+)/gs)  
 
 
    {
        print "MY VAR :\n";
        my $uri=$1;
        print "uri ="; print "$uri\n";
        my $name=$2;
        print "name ="; print "$name\n";        
        my $price=$3;
        print "price ="; print "$price\n";
        $price=~s/^\s+|\s+$//g;
        $price=~s/&nbsp;//g;

        $page{"name"}{$uri}=$name;
        $page{"price"}{$uri}=$price;
    }
    return %page;
}

my %page_old=parse_page($filename);

if(scalar keys %{$page_old{"name"}}>0){
    system("cp $filename ${filename}-1");
}
else{
    %page_old=parse_page("${filename}-1");
}
system("$wget '$url' -O $filename");
my %page_new=parse_page($filename);

if(scalar keys %{$page_old{"name"}}>0){
    if(scalar keys %{$page_new{"name"}}>0){
        my $smstext="";
        foreach my $uri(keys %{$page_new{"name"}})
        {
            if(!defined($page_old{"price"}{$uri})){
                $smstext.="New: ".$page_new{"price"}{$uri}." ".$page_new{"name"}{$uri}." $site$uri\n ";
            }
            elsif($page_new{"price"}{$uri} ne $page_old{"price"}{$uri}){
                $smstext.="Price ".$page_old{"price"}{$uri}." -> ".$page_new{"price"}{$uri}." ".$page_new{"name"}{$uri}." $site$uri\n";
            }
            if(!defined($page_old{"name"}{$uri})){

            }
            elsif($page_new{"name"}{$uri} ne $page_old{"name"}{$uri}){
                $smstext.="Name changed from ".$page_old{"name"}{$uri}." to ".$page_new{"name"}{$uri}." for $site$uri\n";
            }
        }
        if($smstext ne ""){
            sendsms($smstext);
        }
    }
    else{

    }
}
else{
    if(scalar keys %{$page_new{"name"}}<=0){
        sendsms("Error, nothing found for page '$url'");
    }
    else{
        sendsms("Found ".(scalar keys %{$page_new{"name"}})." items, page '$url' monitoring started");
    }
}

foreach my $uri(keys %{$page_new{"name"}})
{
    print "uri: $uri, name: ".$page_new{"name"}{$uri}.", price: ".$page_new{"price"}{$uri}."\n";
    if($page_new{"price"}{$uri} eq $page_old{"price"}{$uri}){print "old price the same\n";}
    else{print "old price = ".$page_old{"price"}{$uri}."\n";}
    if($page_new{"name"}{$uri} eq $page_old{"name"}{$uri}){print "old name the same\n";}
    else{print "old name = ".$page_old{"name"}{$uri}."\n";}

}