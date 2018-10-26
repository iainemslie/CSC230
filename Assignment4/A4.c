/*Iain Emslie*/
/*This program is a stopwatch for an Arduino ATMEGA2560 */
/*Uses a LCD 1602 Board Keypad*/

#include "CSC230.h"
#include <string.h>

#define  ADC_BTN_RIGHT 0x032
#define  ADC_BTN_UP 0x0C3
#define  ADC_BTN_DOWN 0x17C
#define  ADC_BTN_LEFT 0x22B
#define  ADC_BTN_SELECT 0x316
#define  NO_BUTTON 0x3FF

//#define ADC_BTN_RIGHT 0x032
//#define ADC_BTN_UP 0x0FA
//#define ADC_BTN_DOWN 0x1C2
//#define ADC_BTN_LEFT 0x28A
//#define ADC_BTN_SELECT 0x352
//#define  NO_BUTTON 0x3FF

//This global variable is used to count the number of interrupts
//which have occurred. Note that 'int' is a 16-bit type in this case.
int interrupt_count = 0;

//Global variable to track the state of the LED on pin 52.
int LED_state = 0;

//Variables for the basic timer
char min_high, min_low, sec_high, sec_low, tenths = 0;
//For the lap start time
char start_min_high = 0; char start_min_low = 0; char start_sec_high = 0; char start_sec_low = 0; char start_tenths = 0;
//For the lap end time
char end_min_high = 0; char end_min_low = 0; char end_sec_high = 0; char end_sec_low  = 0; char end_tenths = 0;
//Used when printing to LCD screen
char str[1];
//Pause flag is set to 1 when select or reset is pressed and 0 if pressed again
int PAUSE_FLAG = 0;
//Used so that the start lap times are set to zero when lap timer is first pressed
int LAP_FLAG = 0;

/**************************************************************/
/*					---PRINT/RESET FUNCTIONS---				  */
/**************************************************************/

//Set the values of the basic timer to zero
void reset_values(char* min_high, char* min_low, char* sec_high, char* sec_low, char* tenths){
	*min_high = 0;
	*min_low = 0;
	*sec_high = 0;
	*sec_low = 0;
	*tenths = 0;
}
//Set the values of the start laps values to zero
void reset_start_laps(char* start_min_high, char* start_min_low, char* start_sec_high, char* start_sec_low, char* start_tenths){
	*start_min_high = 0;
	*start_min_low = 0;
	*start_sec_high = 0;
	*start_sec_low = 0;
	*start_tenths = 0;
}
//Set the values of the end laps values to zero
void reset_end_laps(char* end_min_high, char* end_min_low, char* end_sec_high, char* end_sec_low, char* end_tenths){
	*end_min_high = 0;
	*end_min_low = 0;
	*end_sec_high = 0;
	*end_sec_low = 0;
	*end_tenths = 0;
}
//Print the values of the timer to the LCD screen
void update_time(char tenths, char sec_low, char sec_high, char min_low, char min_high){
	sprintf(str, "%d%d:%d%d.%d   ", min_high, min_low, sec_high, sec_low, tenths);
	lcd_xy(6,0);
	lcd_puts(str);
}
//Print the values of the start laps to the LCD screen
void update_start_laps(char start_tenths, char start_sec_low, char start_sec_high, char start_min_low, char start_min_high){
	sprintf(str, "%d%d:%d%d.%d", start_min_high, start_min_low, start_sec_high, start_sec_low, start_tenths);
	lcd_xy(0,1);
	lcd_puts(str);
}
//Print the values of the end laps to the LCD screen
void update_end_laps(char end_tenths, char end_sec_low, char end_sec_high, char end_min_low, char end_min_high){
	sprintf(str, "%d%d:%d%d.%d", end_min_high, end_min_low, end_sec_high, end_sec_low, end_tenths);
	lcd_xy(9,1);
	lcd_puts(str);
}

/**************************************************************/
/*					---TIMER FUNCTIONS---					  */
/**************************************************************/

// timer0_setup()
// Set the control registers for timer 0 to enable
// the overflow interrupt and set a prescaler of 1024.
void timer0_setup(){
	//You can also enable output compare mode or use other
	//timers (as you would do in assembly).

	TIMSK0 = 0x02;
	TCNT0 = 0x00;
	TIFR0 = 0x01;

	TCCR0A = 0x02;
	TCCR0B = 0x04; 

	OCR0A = 124;
}

//Define the ISR for the timer 0 overflow interrupt.

ISR(TIMER0_COMPA_vect){

	interrupt_count++;
	if (interrupt_count >= 50){
		interrupt_count -= 50;
			
		tenths++;
		if(tenths == 10){
		tenths = 0;
		sec_low++;
		}

		if(sec_low == 10){
		sec_low = 0;
		sec_high++;
		}

		if(sec_high == 6){
		sec_high = 0;
		min_low++;
		}

		if(min_low == 10){
		min_low = 0;
		min_high++;
		}

		if(min_high == 10){
		min_high = 0;
		}

		update_time(tenths, sec_low, sec_high, min_low, min_high);

	}
}

/**************************************************************/
/*					---BUTTON FUNCTIONS---					  */
/**************************************************************/

//A short is 16 bits wide, so the entire ADC result can be stored
//in an unsigned short.
unsigned short poll_adc(){
	unsigned short adc_result = 0; //16 bits
	
	ADCSRA |= 0x40;
	while((ADCSRA & 0x40) == 0x40); //Busy-wait
	
	unsigned short result_low = ADCL;
	unsigned short result_high = ADCH;
	
	adc_result = (result_high<<8)|result_low;
	return adc_result;
}
//If up button is pressed then update the lap values on the LCD screen
void UP_BUTTON(){
	if(LAP_FLAG == 0){
		LAP_FLAG = 1;
		reset_start_laps(&end_min_high, &end_min_low, &end_sec_high, &end_sec_low, &end_tenths);
		update_start_laps(start_tenths, start_sec_low, start_sec_high, start_min_low, start_min_high);
		update_end_laps(tenths, sec_low, sec_high, min_low, min_high);
		start_min_high = min_high; start_min_low = min_low; start_sec_high = sec_high; start_sec_low = sec_low; start_tenths = tenths;
	}
	else if(LAP_FLAG == 1){
		update_start_laps(start_tenths, start_sec_low, start_sec_high, start_min_low, start_min_high);
		update_end_laps(tenths, sec_low, sec_high, min_low, min_high);
		start_min_high = min_high; start_min_low = min_low; start_sec_high = sec_high; start_sec_low = sec_low; start_tenths = tenths;
	}
	_delay_ms(250);
}
//If down button is pressed then reset the values of the start and end laps and clear the 2nd row of the LCD
void DOWN_BUTTON(){
	reset_end_laps(&start_min_high, &start_min_low, &start_sec_high, &start_sec_low, &start_tenths);
	reset_start_laps(&end_min_high, &end_min_low, &end_sec_high, &end_sec_low, &end_tenths);
	lcd_xy(0,1);
	lcd_puts("                ");
	LAP_FLAG = 0;
}
//If left button is pressed then reset the counter to zero and disable interrupts to stop timer
void LEFT_BUTTON(){
	if(PAUSE_FLAG == 0){
		cli();
		PAUSE_FLAG = 1;
	}
	reset_values(&min_high, &min_low, &sec_high, &sec_low, &tenths);
	update_time(min_high, min_low, sec_high, sec_low, tenths);
	_delay_ms(250);
}
//If select button is pressed then disable/enable interrupts and set flag
void SELECT_BUTTON(){
	if(PAUSE_FLAG == 0){
		cli();
		PAUSE_FLAG = 1;
	}
	else if(PAUSE_FLAG == 1){
		sei();
		PAUSE_FLAG = 0;
	}
	_delay_ms(250);
}

void buttons(){
				
		//ADC Set up
		ADCSRA = 0x87;
		ADMUX = 0x40;
	
		unsigned short adc_result = poll_adc();

		if (adc_result >= 0x00 && adc_result < ADC_BTN_RIGHT){
		//Right Pressed
		}		
		else if (adc_result >= ADC_BTN_RIGHT && adc_result < ADC_BTN_UP){
		//Up button pressed
			UP_BUTTON();
		}
		else if (adc_result >= ADC_BTN_UP && adc_result < ADC_BTN_DOWN){
		//Down button pressed
			DOWN_BUTTON();
		}
		else if (adc_result >= ADC_BTN_DOWN && adc_result < ADC_BTN_LEFT){
		//Left button pressed
			LEFT_BUTTON();
		}
		else if (adc_result >= ADC_BTN_LEFT && adc_result < ADC_BTN_SELECT){
		//Select button pressed
			SELECT_BUTTON();
		}
}


/**************************************************************/
/*					 ---MAIN FUNCTION---					  */
/**************************************************************/


int main(){

	timer0_setup();
	
	//Call LCD init (should only be called once)
	lcd_init();
	
	//Display the string starting at position 0, row 0
	lcd_xy(0,0);
	lcd_puts("Time: 00:00.0");
	
	//Set data direction for Port B
	DDRB = 0xff;

	//Enable interrupts
	//(The sei() function is defined by the AVR library as
	// a wrapper around the sei instruction)
	cli(); 
	//sei();

	while(1){
		buttons();
	}

	return 0;	
}

