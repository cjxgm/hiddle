// vim: noet sts=0 sw=4 ts=4
//
// hiddle - Hybrid Middle Mouse Button
//
// Licensed under the MIT License.
// Copyright (C) 2013 eXerigumo Clanjor (哆啦比猫/兰威举)
//
// CONTRIBUTORS:
// 		eXerigumo Clanjor (哆啦比猫/兰威举) <cjxgm@126.com>
//
// TODO:
// 	*	find a more accurate timing method
//	*	allow the user to set the drag_threshold (getopt?)


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <getopt.h>
#include <err.h>
#include <xdo.h>
#include <time.h>

typedef struct
{
	unsigned int l:1;	// is left     mouse button down?
	unsigned int r:1;	// is    right mouse button down?
	unsigned int m:1;	// is  middle  mouse button down?
	unsigned int  :5;	// I don't know what those value mean.
	char x;
	char y;	// note that this value is actually "-y", I mean, flipped.
}
__attribute__((__packed__))
Event;

typedef enum { MODE_NORMAL, MODE_HOLD, MODE_DRAG, MODE_SCROLL } Mode;


int main(int argc, char * argv[])
{
	int xinput_device_id = -1;
	const char * device_file = "/dev/input/mice";
	int drag_threshold = 10;
	char buf[128];	// for sprintf

	// process arguments
	// "s" for "short" and "l" for "long"
	const   char        soptions[] = "hi:d:";
	const struct option loptions[] = {
		{ "help"  , no_argument      , 0, 'h' },
		{ "id"    , required_argument, 0, 'i' },
		{ "device", required_argument, 0, 'd' },
		{  0      , 0                , 0,  0  },
	};
	int arg;
	while ((arg = getopt_long(argc, argv, soptions, loptions, NULL)) != -1)
		switch (arg) {
			case 'h':
				printf("hiddle - Hybrid Middle Mouse Button\n"
						"\n"
						"Usage: %s [OPTION]...\n"
						"\n"
						"  -h, --help                   show this help.\n"
						"  -i, --id=XINPUT_DEVICE_ID    you can run 'xinput' to see the device id of\n"
						"                               your mouse. If you omit this then it will be\n"
						"                               automatically determined.\n"
						"  -d, --device=DEVICE_FILE     the mouse device located under /dev. If you\n"
						"                               omit this, /dev/input/mice will be used.\n"
						, argv[0]);
				exit(0);
			case 'i': xinput_device_id = atoi(optarg); break;
			case 'd': device_file      =      optarg ; break;
		}
	// automatically determine the xinput_device_id if not set
	if (xinput_device_id == -1) {
		FILE * fp = popen("xinput | grep '[Mm]ouse' | head -n 1 | cut -f2 | cut -d= -f2", "r");
		if (!fp) err(1, "unable to determine xinput_device_id:\n"
				"do you have the following commands?\n"
				"\tsh\n\txinput\n\tgrep\n\thead\n\tcut\n");
		if (fscanf(fp, "%d", &xinput_device_id) != 1)
			err(1, "no mouse found?\n"
					"try to figure out the device id of your mouse with xinput\n");
		fclose(fp);
	}
	if (optind != argc) err(1, "useless trailing argument(s)");

	// open mouse device and set unbuffered mode
	FILE * fp = fopen(device_file, "r");
	if (!fp) err(1, "unable to open device '%s'", device_file);
	if (setvbuf(fp, NULL, _IONBF, 0)) err(1, "unable to set unbuffered mode on '%s'", device_file);

	// init xdo
	xdo_t * xdo = xdo_new(NULL);

	// create and register callback for SIGINT
	void sigint_cb()
	{
		sprintf(buf, "xinput set-button-map %d 1 2 3 4 5 6 7", xinput_device_id);
		system(buf);

		fclose(fp);
		xdo_free(xdo);

		exit(0);
	}
	signal(SIGINT, (void *)sigint_cb);

	// disable middle mouse button
	sprintf(buf, "xinput set-button-map %d 1 0 3 4 5 6 7", xinput_device_id);
	system(buf);

	// the magic part start!
	Event e;
	Mode mode = MODE_NORMAL;
	time_t hold_start = 0;
	int tx, ty;	// temporary relative/absolute position of cursor
	int screen;	// screen number (used in xdo_mouselocation and xdo_mousemove);
	while (1) {
		fread(&e, sizeof(e), 1, fp);
		e.y = -e.y;	// remember? it's flipped!

		switch (mode) {
			case MODE_NORMAL:
				if (e.m) {
					mode = MODE_HOLD;
					hold_start = time(NULL);
					tx = ty = 0;
				}
				break;
			case MODE_HOLD:
				tx += e.x;
				ty += e.y;
				if (time(NULL) == hold_start &&
						(abs(tx) > drag_threshold ||
						 abs(ty) > drag_threshold)) {
					mode = MODE_DRAG;
					xdo_mousedown(xdo, CURRENTWINDOW, 2);
					break;
				}
				else if (time(NULL) != hold_start) {
					xdo_mouselocation(xdo, &tx, &ty, &screen);
					mode = MODE_SCROLL;
					break;
				}
				if (!e.m) {
					mode = MODE_NORMAL;
					if (time(NULL) == hold_start) xdo_click(xdo, CURRENTWINDOW, 2);
				}
				break;
			case MODE_DRAG:
				if (!e.m) {
					mode = MODE_NORMAL;
					xdo_mouseup(xdo, CURRENTWINDOW, 2);
				}
				break;
			case MODE_SCROLL:
				xdo_mousemove(xdo, tx, ty, screen);
				if (e.y < 0) xdo_click(xdo, CURRENTWINDOW, 4);	// scroll up
				if (e.y > 0) xdo_click(xdo, CURRENTWINDOW, 5);	// scroll hold_start
				if (e.x < 0) xdo_click(xdo, CURRENTWINDOW, 6);	// scroll left
				if (e.x > 0) xdo_click(xdo, CURRENTWINDOW, 7);	// scroll right
				if (!e.m) mode = MODE_NORMAL;
				break;
		}
	}

	return 0;
}

