/*
 * COMPLETE 4x4
 *
 */

#define x_size 8
#define y_size 8

/* ---max7221--- */

int max7221_clk = 2;
int max7221_Din = 4;
int max7221_load = 5;

/* ------ */

byte max7219_reg_noop = 0x00;
byte max7219_reg_digit[8] = {0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08};
byte max7219_reg_decodeMode = 0x09;
byte max7219_reg_intensity = 0x0a;
byte max7219_reg_scanLimit = 0x0b;
byte max7219_reg_shutdown = 0x0c;
byte max7219_reg_displayTest = 0x0f;

/* ---Serial Registers--- */

int ic74HC165_Qh = 16;
int ic74HC165_clk = 17;
int ic74HC165_sh_ld = 18;

/* ------ */

int ic74HC164_clk = 15;
int ic74HC164_serial_in = 19;

/* ---USB/Serial Variable--- */

int serial_mapping_x[x_size] = {50,51,52,53,54,55,56,57};
int serial_mapping_y[y_size] = {97,98,99,100,101,102,103,104};
int serial_mapping_polarity[2] = {48,49};

/* ------ */

int incoming_x = 0;
int incoming_y = 0;
int incoming_polarity = 0;

/* ---Software Variables--- */

boolean LED_grid[x_size][y_size];
boolean button_grid[x_size][y_size];

void setup()
{		
	/* ---Hardware Setup--- */

	pinMode(ic74HC165_sh_ld, OUTPUT);
	pinMode(ic74HC165_clk, OUTPUT);
	
	digitalWrite(ic74HC165_sh_ld, LOW);
	digitalWrite(ic74HC165_clk, LOW);
	
	pinMode(ic74HC165_Qh, INPUT);
	
	/* ------ */
	
	pinMode(ic74HC164_serial_in, OUTPUT);
	pinMode(ic74HC164_clk, OUTPUT);
	
	digitalWrite(ic74HC164_serial_in, LOW);
	digitalWrite(ic74HC164_clk, LOW);
	
	ic74HC164_preload();
	
	/* ------ */
	
	pinMode(max7221_Din, OUTPUT);
	pinMode(max7221_clk, OUTPUT);
	pinMode(max7221_load, OUTPUT);
	
	digitalWrite(max7221_Din, LOW);
	digitalWrite(max7221_clk, LOW);
	digitalWrite(max7221_load, LOW);
	
	/* ------ */
	
	max7221_commit(max7219_reg_scanLimit, constrain(x_size-1,0,7));      
	max7221_commit(max7219_reg_decodeMode, 0x00);  // using an led matrix (not digits)
	max7221_commit(max7219_reg_shutdown, 0x01);
	max7221_commit(max7219_reg_displayTest, 0x00); // no display test
	max7221_commit(max7219_reg_intensity, 0x0F);    // the first 0x0F is the value you can set
		
	for(int i = 0; i < x_size; i++) {
		max7221_commit(max7219_reg_digit[i], 0x00);
	}
	
	/* ---Software Setup--- */
	
	reset_grid(false);
	
	/* ---Serial Setup--- */
	
	Serial.begin(57600);
}

/* ------ */

void loop()
{
	outgoing();
	incoming();
}

/* ------ */

void incoming() {
	while (Serial.available() > 2) {
		int ok = 0;
		int x,y;
		boolean polarity;
		
		incoming_x = Serial.read();
		incoming_y = Serial.read();
		incoming_polarity = Serial.read();
		
		for(int i = 0;i < x_size;i++) {
			if(incoming_x == serial_mapping_x[i]) {
				x = i;
				ok++;
			}
		}
		
		for(int i = 0;i < y_size;i++) {
			if(incoming_y == serial_mapping_y[i]) {
				y = i;
				ok++;
			}
		}
		
		if(incoming_polarity == serial_mapping_polarity[0]) {
			polarity = false;
			ok++;
		} else if (incoming_polarity == serial_mapping_polarity[1]) {
			polarity = true;
			ok++;
		}
		
		if(ok != 3) {
//			Serial.print("Error! ... skipping one char");
//			Serial.println();
			while(Serial.available() < 1) {
				delay(1);
			}
			Serial.read();
		} else {
			LED_grid[x][y] = polarity;
			
			redraw_column(x);

//			Serial.print("I received: ");
//			Serial.println(x, DEC);
//			Serial.print("I received: ");
//			Serial.println(y, DEC);
//			Serial.print("I received: ");
//			Serial.println(polarity, DEC);
//			Serial.println();
		}
	}
}

void redraw_column(int i) {
	byte column_state = 0x00;
	for(int j= 0;j < y_size; j++) {
		if(LED_grid[i][j]) {
			column_state += 0x01 << j;
		}
	}
	max7221_commit(max7219_reg_digit[i],column_state);
}

void max7221_commit(byte reg, byte data) {
	max7221_loadByte(reg);
	max7221_loadByte(data);
	pulse(max7221_load);
}

void max7221_loadByte(byte data) {
	byte i = 8;
	byte mask;
	while(i > 0) {
		mask = 0x01 << (i - 1);
		digitalWrite(max7221_clk, LOW);
		
		if (data & mask){
			digitalWrite(max7221_Din, HIGH);
		} else {
			digitalWrite(max7221_Din, LOW);
		}
		
		digitalWrite(max7221_clk, HIGH);
		i--;
	}
}

void reset_grid(boolean polarity) {
	for(int i = 0;i < x_size;i++) {
		for(int j= 0;j < y_size; j++) {	
			LED_grid[i][j] = polarity;
		}
	}
}

/* ------ */

void outgoing() {
	for(int i = 0;i < x_size;i++) {
		digitalWrite(ic74HC165_sh_ld, HIGH);
		
		for(int j = 0;j < y_size;j++) {
			if(digitalRead(ic74HC165_Qh) == HIGH) {
				if(button_grid[i][j] != true) {
					button_grid[i][j] = true;
					Serial.print(serial_mapping_x[i], BYTE);
					Serial.print(serial_mapping_y[j], BYTE);
					Serial.print(serial_mapping_polarity[1], BYTE);
					Serial.println();
				}
			} else {
				if(button_grid[i][j] != false) {
					button_grid[i][j] = false;
					Serial.print(serial_mapping_x[i], BYTE);
					Serial.print(serial_mapping_y[j], BYTE);
					Serial.print(serial_mapping_polarity[0], BYTE);
					Serial.println();
				}
			}
			pulse(ic74HC165_clk);
		}
		
		digitalWrite(ic74HC165_sh_ld, LOW);
		
		if(i < (x_size-1)) {
			digitalWrite(ic74HC164_serial_in, LOW);
			pulse(ic74HC164_clk);
		} else {	
			digitalWrite(ic74HC164_serial_in, HIGH);
			pulse(ic74HC164_clk);
		}
	}
}

void ic74HC164_preload() {
	digitalWrite(ic74HC164_serial_in, LOW);
	for(int i = 0;i < x_size;i++) {
		pulse(ic74HC164_clk);
	}
	
	digitalWrite(ic74HC164_serial_in, HIGH);
	pulse(ic74HC164_clk);
	
	digitalWrite(ic74HC164_serial_in, LOW);
}

/* ------ */

void pulse(int pin) {
	digitalWrite(pin, HIGH);
	digitalWrite(pin, LOW);
}