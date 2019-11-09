#!/bin/bash
## KIIP Tools
## - Konversi aac ke mp3 dan menggenerate 2 file dengan bitrate 32kbps dan 24kbps
## - Dan me-rename file ke tanggal rekam

USAGE() {
    printf "KIIP Tools - CLI Tool yang digunakan untuk mengkonversi file rekaman kajian menjadi versi 32kbps dan 24kbps"
    printf " serta mengisi ID3 tag menyesuaikan dengan materi dan pemateri kajian.\n"
    printf "\nPenggunaan:"
    printf " ${0} FILE_REKAMAN [[-pjbk] ARGUMEN] [-qcnos]\n"
    exit 0
}

if ! type ffmpeg > /dev/null; then
    echo "ffmpeg belum terpasang"
    exit 1
elif ! type sox > /dev/null; then
    echo "sox belum terpasang"
    exit 1
fi

if [[ $# -gt 0 ]]; then
    FILE="$1"
    FILENAME=$(basename -- "$file")
    ext="${FILENAME##*.}"
    FILENAME="${FILENAME%.*}"
    tanggal=$(stat -c '%y' "$file" | cut -d " " -f 1 | { read dat; date -d "$dat" +%d-%m-%Y; })
    tanggalnamafile=$(stat -c '%y' "$file" | cut -d " " -f 1 | { read dat; date -d "$dat" +%A-%d%B%Y; })
    OUTPUTFILE="${tanggalnamafile}"
    shift
else
    USAGE
    exit 0
fi

# Variables
FILE=""
PEMATERI=""
JUDUL=""
KITAB=""
BAG=""
ENCODEDBY="Kajian Islam Ilmiyah Probolinggo"
CEPAT=false
SKIP=false
OVRWRITE=""
NOISEFILTER=false
VERBOOSITY="-v quiet -stats"
OUTPATH="output/"

if [[ $# -eq 0 ]]; then
    read -p "Pemateri: " PEMATERI
    read -p "Judul: " JUDUL
    read -p "Kitab: " KITAB
    read -p "Bagian ke: " BAG
fi

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		-p|--pemateri)
		    # Pemateri Rekaman
		    PEMATERI="$2"
		    shift
		    shift
		    ;;
		-j|--judul)
		    # Judul Kajian
		    JUDUL="$2"
		    shift
		    shift
		    ;;
		-k|--kitab)
		    # Pembahasan Kitab
		    KITAB="$2"
		    shift
		    shift
		    ;;
		-b|--bagian)
		    # Pembahasan ke-n
            BAG="$2"
		    shift
		    shift
		    ;;
        -c|--cepat)
            CEPAT=true
            shift
            ;;
        -s|--skip)
            SKIP=true
            shift
            ;;
        -o|--overwrite)
            OVRWRITE="-y"
            shift
            ;;
        -n|--noisefilter)
            NOISEFILTER=true
            shift
            ;;
        -q|--quiet)
            VERBOOSITY=""
            shift
            ;;
		*)
            POSITIONAL+=("$1")
		    ;;
	esac
done

## Functions ##

KONVERSI() {
        # Print detail jika opsi -q tidak dipakai
        if [[ "$VERBOOSITY"  != "" ]]; then
            echo "======== KIIP Tools ========"
            printf " Pemateri: \t$PEMATERI\n"
            printf " Judul: \t$JUDUL\n"
            printf " Kitab: \t$KITAB\n"
            printf " Bagian ke: \t$BAG\n"
            printf " Tanggal: \t$tanggal\n"
            echo "============================"
        fi

        # Konfirmasi konversi jika opsi -q dan/atau -c tidak dipakai
        if [[ "$SKIP" == false  ]] || [[ "$VERBOOSITY" != "" ]]; then
            read -p "Lakukan konversi? (Y)" -n 1 -r
            echo
            if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi

        # Membuat output folder
        if [ ! -d "$OUTPATH" ]; then
            mkdir -p $OUTPATH{24k,32k}
        fi

        # Penamaan file output
        if [[ "$CEPAT" == false ]]; then
            read -ra NAMA <<< "$PEMATERI"
            if [[ "${NAMA[1]}" == "Abu" ]]; then
                NAMA="${NAMA[0]:3} ${NAMA[3]}"
            elif [[ ${#NAMA[@]} == "4" ]]; then
                NAMA="${NAMA[0]:3} ${NAMA[@]:1:2}"
            else
                NAMA="${NAMA[0]:3} ${NAMA[1]}"
            fi
            OUTPUTFILE="${JUDUL}(${BAG})_${KITAB}-${NAMA}"
        fi

        # Menghasilkan Noise-filtered output
        if [[ "$NOISEFILTER" == true ]]; then
            if [ ! -d "tmp" ]; then
                echo "Membuat direktori temporer"
                mkdir ./tmp
            fi

            ## Warning
            if [[ $SKIP == false ]]; then
                read -p "Pastikan rekaman tidak langsung dimulai pada detik awal. (Y)" -n 1 -r
                echo
                if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
                    exit 0
                fi
            fi

            # Mengambil sampel noise dari 2 detik pertama rekaman
            ffmpeg -v quiet -stats -i "$FILE" -vn -ss 00:00:00 -t 00:00:02 -acodec libmp3lame tmp/sample.mp3
            sox tmp/sample.mp3 -n noiseprof tmp/noiseprofile

            # Mengkonversi non-filtered audio ke folder temporer
            ffmpeg $VERBOOSITY -i "$FILE" -c copy -map_metadata -1 -metadata title="$JUDUL" -metadata artist="$PEMATERI" -metadata album="$KITAB" -metadata track="$BAG" -metadata genre="Dakwah" -metadata date="$tanggal" -metadata encoded_by="$ENCODEDBY" -acodec libmp3lame -b:a 32k tmp/32.mp3
            ffmpeg $VERBOOSITY -i "$FILE" -c copy -map_metadata -1 -metadata title="$JUDUL" -metadata artist="$PEMATERI" -metadata album="$KITAB" -metadata track="$BAG" -metadata genre="Dakwah" -metadata date="$tanggal" -metadata encoded_by="$ENCODEDBY" -acodec libmp3lame -ar 24000 -b:a 24k tmp/24.mp3

            # Noise filtering
            echo "Menkonversi audio..."
            sox tmp/32.mp3 "${OUTPATH}"32k/"${OUTPUTFILE}.mp3" noisered tmp/noiseprofile 0.2 -S && ls "${OUTPATH}"32k/"${OUTPUTFILE}.mp3"
            sox tmp/24.mp3 "${OUTPATH}"24k/"${OUTPUTFILE}.mp3"  noisered tmp/noiseprofile 0.2 -S && ls "${OUTPATH}"24k/"${OUTPUTFILE}.mp3" &&

            echo "Selesai"
            rm -rf ./tmp
        else
            # Konversi tanpa noise reduction
            echo "Sedang mengkonversi ${FILE} 32kbps => "${OUTPATH}"32k/${OUTPUTFILE}.mp3"
            ffmpeg $VERBOOSITY -i "$FILE" -c copy -map_metadata -1 -metadata title="$JUDUL" -metadata artist="$PEMATERI" -metadata album="$KITAB" -metadata track="$BAG" -metadata genre="Dakwah" -metadata date="$tanggal" -metadata encoded_by="$ENCODEDBY" -acodec libmp3lame -b:a 32k ./"${OUTPATH}"32k/"${OUTPUTFILE}.mp3" $OVRWRITE

            if [ $? -eq 0 ]; then
                echo "$(date +'%A %d-%m-%Y %r') $FILE --> ${OUTPATH}32k/${OUTPUTFILE}.mp3" >> ./.log-converted
            fi

            echo "Sedang mengkonversi ${FILE} 24kbps => "${OUTPATH}"24k/${OUTPUTFILE}.mp3"
            ffmpeg $VERBOOSITY -i "$FILE" -c copy -map_metadata -1 -metadata title="$JUDUL" -metadata artist="$PEMATERI" -metadata album="$KITAB" -metadata track="$BAG" -metadata genre="Dakwah" -metadata date="$tanggal" -metadata encoded_by="$ENCODEDBY" -acodec libmp3lame -ar 24000 -b:a 24k ./"${OUTPATH}"24k/"${OUTPUTFILE}.mp3" $OVRWRITE

            if [ $? -eq 0 ]; then
                echo "$(date +'%A %d-%m-%Y %r') $FILE --> ${OUTPATH}32k/${OUTPUTFILE}.mp3" >> ./.log-converted
            fi

            echo "Selesai"
        fi
        exit 0
}

KONVERSI
