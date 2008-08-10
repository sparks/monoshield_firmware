/*
 * COMPLETE 4x4
 *
 */

#define x_size 8
#define y_size 8

/* ---USB/Serial--- */

byte incoming_data0 = 0x00;
byte incoming_data1 = 0x00;

int stray_byte_counter = 0;

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

/* ---Software--- */

boolean LED_grid[x_size][y_size];
boolean button_grid[x_size][y_size];

void setup()
{
	/* ---USB/Serial--- */

	Serial.begin(9600);
		
	/* ---max7221--- */
	
	pinMode(max7221_Din, OUTPUT);
	pinMode(max7221_clk, OUTPUT);
	pinMode(max7221_load, OUTPUT);
	
	digitalWrite(max7221_Din, LOW);
	digitalWrite(max7221_clk, LOW);
	digitalWrite(max7221_load, LOW);
	
	/* ------ */
	
	max7221_commit(max7219_reg_scanLimit, constrain(x_size-1,0,7)); //Only scan as far as necessary
	max7221_commit(max7219_reg_decodeMode, 0x00); //Decode as an LED matrix
	max7221_commit(max7219_reg_shutdown, 0x01);
	max7221_commit(max7219_reg_displayTest, 0x00); //0x00 for normal operation - 0xFF to test
	max7221_commit(max7219_reg_intensity, 0x0F); //Value from 0x00 to 0x0F for intensity
		
	for(int i = 0; i < x_size; i++) {
		max7221_commit(max7219_reg_digit[i], 0x00); //Turn off all LEDs
	}
	
	/* ---Serial Registers--- */

	pinMode(ic74HC165_Qh, INPUT);

	pinMode(ic74HC165_clk, OUTPUT);
	pinMode(ic74HC165_sh_ld, OUTPUT);
	
	digitalWrite(ic74HC165_clk, LOW);
	digitalWrite(ic74HC165_sh_ld, LOW);
		
	/* ------ */
	
	pinMode(ic74HC164_clk, OUTPUT);
	pinMode(ic74HC164_serial_in, OUTPUT);
	
	digitalWrite(ic74HC164_clk, LOW);
	digitalWrite(ic74HC164_serial_in, LOW);
	
	ic74HC164_preload();
	
	/* ---Software--- */
	
	reset_grid(false);
}

/* ---Main Loop--- */

void loop()
{
	outgoing();
	incoming();
}

/* ---USB/Serial--- */

void outgoing() {
	byte data0 = 0x00;
	byte data1 = 0x00;
	
	for(byte i = 0;i < x_size;i++) {
		
		digitalWrite(ic74HC165_sh_ld, HIGH);
		
		for(byte j = 0;j < y_size;j++) {
			
			if(digitalRead(ic74HC165_Qh) == HIGH && button_grid[i][j] == false) {
				button_grid[i][j] = true;
				data0 = 0x01;
				data1 = j << 4 | i;
				Serial.print(data0,BYTE);
				Serial.print(data1,BYTE);
				
			/*	Serial.print("Button ");
				Serial.print(j,DEC);
				Serial.print(",");
				Serial.print(i,DEC);
				Serial.println(" is pressed");
				Serial.println(); */
			} else if(digitalRead(ic74HC165_Qh) == LOW && button_grid[i][j] == true){
				button_grid[i][j] = false;
				data0 = 0x00;
				data1 = j << 4 | i;
				Serial.print(data0,BYTE);
				Serial.print(data1,BYTE);
				
			/*	Serial.print("Button ");
				Serial.print(j,DEC);
				Serial.print(",");
				Serial.print(i,DEC);
				Serial.println(" is released");
				Serial.println(); */
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

/* ------ */

void incoming() {
	while (Serial.available() > 1) {
		
		incoming_data0 = Serial.read();
		incoming_data1 = Serial.read();
		
		switch((incoming_data0 & 0xF0) >> 4) {
			case 0x02: //led
				LED_grid[constrain((incoming_data1 & 0xF0) >> 4,0,x_size-1)][constrain(incoming_data1 & 0x0F,0,y_size-1)] = incoming_data0 & 0x0F;
				redraw_column((incoming_data1 & 0xF0) >> 4);
			/*	Serial.print("I received: ");
				Serial.println((incoming_data1 & 0xF0) >> 4, DEC);
				Serial.print("I received: ");
				Serial.println(incoming_data1 & 0x0F, DEC);
				Serial.print("I received: ");
				Serial.println(incoming_data0 & 0x0F, DEC);
				Serial.println(); */
			break;
			case 0x03: //led intensity
				max7221_commit(max7219_reg_intensity, incoming_data1 & 0x0F);
			break;
			case 0x04: //led test
				if(incoming_data1 & 0x0F) {
					max7221_commit(max7219_reg_displayTest, 0x01);
				} else {
					max7221_commit(max7219_reg_displayTest, 0x00);
				}
			break;
			case 0x05: //adc_enable
				delay(1); //NOT IMPLEMENTED AS OF NOW
			break;
			case 0x06: //shutdown
				if(incoming_data1 & 0x0F) {
					max7221_commit(max7219_reg_shutdown, 0x00);
				} else {
					max7221_commit(max7219_reg_shutdown, 0x01);
				}
			break;
			case 0x07: //led_row
				int row = constrain(incoming_data0 & 0x0F,0,y_size-1);
				for(int i = 0;i < x_size;i++) {
					LED_grid[i][row] = incoming_data1 & (0x01 << i);
					redraw_column(i);
				}
			break;
			case 0x08: //led_col
				int col = constrain(incoming_data0 & 0x0F,0,x_size-1);
				for(int j = 0;j < y_size;j++) {
					LED_grid[col][j] = incoming_data1 & (0x01 << j);
				}
				redraw_column(col);
			break;
		}
	}
		
	/* ---Test for out of sync bytes--- */
	/* ---!!!!!!!Keep this commented out for manual testing!!!!!!--- */
			
/*	if(Serial.available() == 1) {
		if(stray_byte_counter >= 80) {
		//	Serial.print("Error! ... skipping one byte");
		//	Serial.println();
			Serial.read();
			stray_byte_counter = 0;
		} else {
			stray_byte_counter++;
		}			
	}*/
}

/* ---max7221--- */

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
		
		if (data & mask){
			digitalWrite(max7221_Din, HIGH);
		} else {
			digitalWrite(max7221_Din, LOW);
		}
		
		pulse(max7221_clk);
		i--;
	}
}

/* ---Serial Registers--- */

void ic74HC164_preload() {
	digitalWrite(ic74HC164_serial_in, LOW);
	for(int i = 0;i < x_size;i++) {
		pulse(ic74HC164_clk);
	}
	
	digitalWrite(ic74HC164_serial_in, HIGH);
	pulse(ic74HC164_clk);
	
	digitalWrite(ic74HC164_serial_in, LOW);
}


/* ---Software--- */

void reset_grid(boolean polarity) {
	for(int i = 0;i < x_size;i++) {
		for(int j= 0;j < y_size; j++) {	
			LED_grid[i][j] = polarity;
		}
		redraw_column(i);
	}
}

void redraw_column(int i) {
	byte column_state = 0x00;
	for(int j= 0;j < y_size; j++) {
		if(LED_grid[i][j]) {
			column_state |= 0x01 << j;
		}
	}
	max7221_commit(max7219_reg_digit[i],column_state);
}

/* ------ */

void pulse(int pin) {
	digitalWrite(pin, HIGH);
	digitalWrite(pin, LOW);
}