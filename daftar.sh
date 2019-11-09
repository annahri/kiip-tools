#!/bin/bash

source $HOME/KIIP/jadwal

if [ ! $# -gt 0 ]; then
for f in *.mp3; do
    pekan=$(dconv $(date -r "$f" +%F) -f %c)
    tanggal=$(date -r "$f" +%d)
    hari=$(date -r "$f" +%A)
    bulan=$(date -r "$f" +%B)
    pemateri=""
    case $hari in
        Senin)
            pemateri="$SENIN"
        ;;
        Selasa)
            [ $((pekan%2)) -eq 0 ] && pemateri="$SELASA0"
            pemateri="$SELASA1"
        ;;
        Kamis)
            pemateri="$KAMIS"
        ;;
        Jumat)
            case $pekan in
                01)
                    pemateri="$JUMAT1"
                ;;
                02)
                    pemateri="$JUMAT2"
                ;;
                03)
                    pemateri="$JUMAT3"
                ;;
                04)
                    pemateri="$JUMAT4"
                ;;
                05)
                    pemateri="$JUMAT5"
                ;;
            esac
        ;;
        *)
        ;;
    esac
    echo "$f -- $hari (${pekan}) $tanggal $bulan -- $pemateri"; 
done
fi