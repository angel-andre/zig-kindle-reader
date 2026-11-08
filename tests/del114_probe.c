#include <stdio.h>
int zr_safe_delete(const char *root, const char *path);
int main(int c, char **v){ printf("%d\n", zr_safe_delete(v[1], v[2])); return 0; }
