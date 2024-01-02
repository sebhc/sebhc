/* box.c - draw a box on SigmaSoft graphics display
**
*/
#include "printf.h"

#define	SOH	'\001'
#define ESC	'\033'

int ig, x1, x2, y1, y2;

/* cmd - issue command to IGC */
cmd(s)
char *s;
{
	printf("%c%s\n",SOH,s);
}

main()
{
	int i;
	
	if ((ig = fopen("IG:", "w")) == 0)
		printf("Unable to open IG device driver\n");
	else {
		x1 = -200;
		y1 = 200;
		x2 = 200;
		y2 = -200;

		/* clear  H19 screen */
		printf("%cE",ESC);
		
		/* initiate IGC */
		cmd("Reset");
		cmd("Clear");
		cmd("Mode +Pixel");
	
		/* draw concentric boxes */
		for (i=0; i<10; i++) {
			printf("%cBox %d %d %d %d\n",SOH, x1, y1, x2, y2);
			x1+=5;
			y1-=5;
			x2-=5;
			y2+=5;
		}

		fclose(ig);
	}
}
