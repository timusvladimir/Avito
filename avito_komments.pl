#!/usr/bin/perl

use strict; # обязывает использовать директивы для повышения качества кода и обеспечения его безопасности
use MIME::Lite; # используется для отправки электронной почты через SMTP
undef $/; # это делает разделитель записи (Input Record Separator) undef, что позволяет читать весь файл целиком в одну строку

my $url=$ARGV[0]; # присваивает переменной $url первый аргумент командной строки, переданный скрипту.
my $mailer="ssmtp";
my $wget="wget";

if($url eq ""){
    print "Usage: avito.pl <https://www.avito.ru/...url>";
    exit;
} # Если не был передан URL, скрипт выводит сообщение о том, как использовать скрипт, и завершает выполнение.

my $filename=$url; # присваивает переменной $filename значение $url.
$filename=~s#[^A-Za-z0-9\.]#_#g; #
$url=~m#(^.*?://.*?)/#;
my $site=$1;
print "site:".$site."\n";

sub sendsms {
    my $text=shift;
   # $text=~s/_/%5F/g;
    my $msg = MIME::Lite->new(  From    => '*******@mail.ru',
                                To      => '********@gmail.com',
                                Subject => 'avitoshka',
                                Type    => 'text/plain; charset=UTF-8',
                                Data    => "$text" );
    $msg->send();
} # sendsms — подпрограмма для отправки SMS. Создает объект MIME::Lite для отправки сообщения на указанный адрес.

sub parse_page {
    open(MYFILE,"<".shift);
    my $text=<MYFILE>;
    close(MYFILE);
    my %page;
    
# test 
#    while($text=~/<div class=\"description\">.*?<h3 class=\"title 
# item-description-title\"> <a class=\"item-description-title-link\" 
# href=\"(.*?)\".*?>\n(.*?)\n.*?<div class=\"about\">\n\s*(\S*)/gs)

#        while($text=~/<div class=\"item_table-wrapper\">.*?<a class="item-description-title-link"
# itemprop="url"
# href=\"(.*?)\".*?> <span itemprop=\"name"\>(\D*).*?<span
# class=\"price \".*?>\n\s*(\d+)/gs)  
 
# while($text=~/<div class=\"item_table-wrapper\">.*?<a class="item-description-title-link"
# itemprop="url"
# href=\"(.*?)\".*?> <span itemprop=\"name"\>(\D*).*?<span
# class=\"price \".*?>\n\s*(\w+\s\w+)/gs)  
  
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
       # $uri=~s/^\s+|\s+$//g;
       # $name=~s/^\s+|\s+$//g;
         $price=~s/^\s+|\s+$//g;
        $price=~s/&nbsp;//g;

        $page{"name"}{$uri}=$name;
        $page{"price"}{$uri}=$price;
    }
    return %page;
} # parse_page — подпрограмма для парсинга HTML-страницы. Открывает файл, считывает его содержимое, используя регулярные выражения для извлечения данных о товарах (URI, название, цена) и сохраняет их в хэш %page.

my %page_old=parse_page($filename); # Вызывает parse_page для указанного файла (URL).

if(scalar keys %{$page_old{"name"}}>0){
    system("cp $filename ${filename}-1");
}
else{
    %page_old=parse_page("${filename}-1");
} # Проверяет, есть ли какие-либо сохраненные данные. Если они есть, создает резервную копию файла данных. В противном случае, загружает данные из резервной копии.

system("$wget '$url' -O $filename");
my %page_new=parse_page($filename); # Использует утилиту wget для загрузки указанной веб-страницы и сохранения ее содержимого в файле. Затем парсит загруженную страницу и сохраняет данные в %page_new.

if(scalar keys %{$page_old{"name"}}>0){ # already have previous successful search
    if(scalar keys %{$page_new{"name"}}>0){ # both searches have been successful
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
                # already done for price
            }
            elsif($page_new{"name"}{$uri} ne $page_old{"name"}{$uri}){
                $smstext.="Name changed from ".$page_old{"name"}{$uri}." to ".$page_new{"name"}{$uri}." for $site$uri\n";
            }
        }
        if($smstext ne ""){
            sendsms($smstext);
        }
    }
    else{ # previous search is successful, but current one is failed
        # do nothing, probably a temporary problem
    }
}
else{ # is new search
    if(scalar keys %{$page_new{"name"}}<=0){ # both this and previous have been failed
        sendsms("Error, nothing found for page '$url'");
    }
    else{ # successful search and items found
        sendsms("Found ".(scalar keys %{$page_new{"name"}})." items, page '$url' monitoring started");
    }
} # Сравнивает новые данные с предыдущими. Если был успешный предыдущий поиск (scalar keys %{$page_old{"name"}}>0), сравнивает цены и названия товаров. Если был успешный текущий поиск (scalar keys %{$page_new{"name"}}>0), формирует текст сообщения о найденных изменениях и отправляет его через sendsms.

foreach my $uri(keys %{$page_new{"name"}})
{
    print "uri: $uri, name: ".$page_new{"name"}{$uri}.", price: ".$page_new{"price"}{$uri}."\n";
    if($page_new{"price"}{$uri} eq $page_old{"price"}{$uri}){print "old price the same\n";}
    else{print "old price = ".$page_old{"price"}{$uri}."\n";}
    if($page_new{"name"}{$uri} eq $page_old{"name"}{$uri}){print "old name the same\n";}
    else{print "old name = ".$page_old{"name"}{$uri}."\n";}

}