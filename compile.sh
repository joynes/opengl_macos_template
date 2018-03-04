clang++ -fsanitize=address $DISABLED -g3 -framework AppKit -std=c++11 -framework OpenGl -framework CoreVideo Coopgame.mm && ./a.out
