#!/bin/sh
cd "$PROJECT_DIR"/wireguard-go-bridge
case $1 in
  clean)
    make clean
    ;;
  *)
   if [ -e "$DERIVED_FILE_DIR/libwg-go.a" ]
   then
     echo "Clean before building"
   else
     make
   fi

    ;;
esac

if [ -f "libwg-go.a" ]
then
	mkdir -p "$DERIVED_FILE_DIR"
	mv *.a "$DERIVED_FILE_DIR"
	ln -sf "$DERIVED_FILE_DIR/libwg-go.a" libwg-go.a
fi
