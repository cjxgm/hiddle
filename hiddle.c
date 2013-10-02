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
// 	*	customizable time


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <getopt.h>
#include <err.h>
#include <xdo.h>
#include <time.h>
#include <config.h>

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

time_t time_ms()
{
	struct timespec tp;
	clock_gettime(CLOCK_BOOTTIME, &tp);
	return tp.tv_sec*1000 + tp.tv_nsec/1000000;
}


int main(int argc, char * argv[])
{
	int xinput_device_id = -1;
	const char * device_file = "/dev/input/mice";
	int drag_threshold = 20;
	time_t scroll_delay = 500;
	char buf[128];	// for sprintf

	// process arguments
	// "s" for "short" and "l" for "long"
	const   char        soptions[] = "ht:i:d:";
	const struct option loptions[] = {
		{ "help"             , no_argument      , NULL, 'h' },
		{ "threshold"        , required_argument, NULL, 't' },
		{ "id"               , required_argument, NULL, 'i' },
		{ "device"           , required_argument, NULL, 'd' },
		{  NULL              , 0                , NULL,  0  },
	};
	int arg;
	while ((arg = getopt_long(argc, argv, soptions, loptions, NULL)) != -1)
		switch (arg) {
			case 'h':
				printf(APP_NAME " - Hybrid Middle Mouse Button\n"
						"version: " APP_VER "\n"
						"\n"
						"  middle mouse click           For short: click\n"
						"                               hold down middle mouse button, don't move your\n"
						"                               mouse or move only within the drag threshold,\n"
						"                               then release middle mouse button.\n"
						"\n"
						"  middle mouse drag            For short: hold, move immediately\n"
						"                               hold down middle mouse button, move your mouse\n"
						"                               more than the drag threshold within 1 second.\n"
						"\n"
						"  middle mouse scroll          For short: hold, wait for 1 second, move\n"
						"                               hold down middle mouse button, don't move your\n"
						"                               mouse or move only within the drag threshold,\n"
						"                               after 1 second then move your mouse to scroll.\n"
						"\n"
						"\n"
						"Usage: %s [OPTION]...\n"
						"\n"
						"  -h, --help                   show this help.\n"
						"  -t, --threshold=PIXELS       set the drag threshold to PIXELS. \n"
						"                               default is 20.\n"
						"  -i, --id=ID                  ID is the mouse device id got from 'xinput'.\n"
						"                               you can run 'xinput' to see it. If you omit\n"
						"                               this, it will be automatically determined.\n"
						"  -d, --device=FILE            FILE is the mouse device located under /dev.\n"
						"                               default is '/dev/input/mice'.\n"
						, argv[0]);
				exit(0);
			case 't': drag_threshold   = atoi(optarg); break;
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
	int scroll;
	while (1) {
		fread(&e, sizeof(e), 1, fp);
		e.y = -e.y;	// remember? it's flipped!

		switch (mode) {
			case MODE_NORMAL:
				if (e.m) {
					mode = MODE_HOLD;
					hold_start = time_ms();
					tx = ty = 0;
				}
				break;
			case MODE_HOLD:
				tx += e.x;
				ty += e.y;
				scroll = (time_ms()-hold_start >= scroll_delay);
				if (!scroll &&
						(abs(tx) > drag_threshold ||
						 abs(ty) > drag_threshold)) {
					mode = MODE_DRAG;
					xdo_mousedown(xdo, CURRENTWINDOW, 2);
					break;
				}
				else if (scroll) {
					xdo_mouselocation(xdo, &tx, &ty, &screen);
					mode = MODE_SCROLL;
					putc('\a', stderr);
					break;
				}
				if (!e.m) {
					mode = MODE_NORMAL;
					if (!scroll) xdo_click(xdo, CURRENTWINDOW, 2);
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

