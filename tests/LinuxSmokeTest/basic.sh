#!/bin/sh

[ "$1" ] || exit 1
trojan=$(realpath $1)
tmpdir=$(mktemp -d)
echo Test directory is $tmpdir.
cp server.json client.json forward.json $tmpdir
cd $tmpdir
exec 2>> test.log

yes '' | openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 1 -nodes

mkdir true fake
echo true > true/whoami.txt
echo fake > fake/whoami.txt

cd true
python3 -m http.server 10081 > server.log 2>&1 &
pid1=$!
cd ..

cd fake
python3 -m http.server 10080 > server.log 2>&1 &
pid2=$!
cd ..

$trojan -v
$trojan -t server.json
$trojan server.json -l server.log &
pid3=$!
$trojan -t client.json
$trojan client.json -l client.log &
pid4=$!
$trojan -t forward.json
$trojan forward.json -l forward.log &
pid5=$!

sleep 2

whoami=$(curl -v --socks5 127.0.0.1:11080 http://127.0.0.1:10081/whoami.txt)
whoami2=$(curl -v http://127.0.0.1:20081/whoami.txt)
kill $pid1 $pid2 $pid3 $pid4 $pid5
if [ "$whoami" = true -a "$whoami2" = true ]; then
    rm -rf $tmpdir
    echo PASS
    exit 0
else
    echo FAIL
    exit 1
fi
