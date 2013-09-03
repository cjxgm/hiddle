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
//	*	allow the user to set the "drag or scroll" threshold time
//	*	add a time threshold that, if you release the middle button within
//		the time, it will alwayes generate a middle click, even if you
//		moved the mouse.


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <err.h>
#include <xdo.h>
#include <time.h>

typedef struct Event
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

typedef enum Mode
{
	MODE_NORMAL,
	MODE_HOLD,
	MODE_DRAG,
	MODE_SCROLL,
}
Mode;

static void show_help(const char * app)
{
	printf("%s [xinput_device_id [device_file]]\n"
			"%s --help\n"
			"%s -h\n\n"
			"--help, -h         show this help.\n"
			"xinput_device_id   you can run 'xinput' and see the device id of\n"
			"                   your mouse. If you omit this then it will be\n"
			"                   automatically determined.\n"
			"device_file        the mouse device located under /dev. If you omit\n"
			"                   this, /dev/input/mice will be used.\n",
			app, app, app);
}

int main(int argc, char * argv[])
{
	int xinput_device_id = 0;
	const char * device_file = "/dev/input/mice";
	static char buf[128];	// for sprintf

	// process arguments
	if (argc > 3) {
		show_help(argv[0]);
		return 0;
	}
	if (argc == 2 &&
			(!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))) {
		show_help(argv[0]);
		return 0;
	}
	if (argc == 1) {
		FILE * fp = popen("xinput | grep '[Mm]ouse' | head -n 1 | cut -f2 | cut -d= -f2", "r");
		if (!fp) err(1, "unable to determine xinput_device_id:\n"
				"do you have the following commands?\n"
				"\tsh\n\txinput\n\tgrep\n\thead\n\tcut\n");
		if (fscanf(fp, "%d", &xinput_device_id) != 1)
			err(1, "no mouse found?\n"
					"try to figure out the device id of your mouse with xinput.");
		fclose(fp);
	}
	else xinput_device_id = atoi(argv[1]);
	if (argc == 3) device_file = argv[2];

	// open mouse device and set unbuffered mode
	FILE * fp = fopen(device_file, "r");
	if (!fp) err(1, "unable to open device %s.", device_file);
	if (setvbuf(fp, NULL, _IONBF, 0)) err(1, "unable to set unbuffered mode.");

	// init xdo
	xdo_t * xdo = xdo_new(NULL);

	// create and register callback for SIGINT and at_exit
	void exit_cb()
	{
		sprintf(buf, "xinput set-button-map %d 1 2 3 4 5 6 7", xinput_device_id);
		system(buf);

		fclose(fp);
		xdo_free(xdo);
	}
	signal(SIGINT, (void *)exit_cb);
	atexit(exit_cb);

	// disable middle mouse button
	sprintf(buf, "xinput set-button-map %d 1 0 3 4 5 6 7", xinput_device_id);
	system(buf);

	// the magic part start!
	Event e;
	Mode mode = MODE_NORMAL;
	time_t hold_start = 0;
	while (1) {
		fread(&e, sizeof(e), 1, fp);
		e.y = -e.y;	// remember? it's flipped!

		switch (mode) {
			case MODE_NORMAL:
				if (e.m) {
					mode = MODE_HOLD;
					hold_start = time(NULL);
				}
				break;
			case MODE_HOLD:
				if (e.x || e.y) {
					if (time(NULL) == hold_start) {
						mode = MODE_DRAG;
						xdo_mousedown(xdo, CURRENTWINDOW, 2);
					}
					else mode = MODE_SCROLL;
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

