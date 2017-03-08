.include "m2560def.inc"
.def temp1 = r17
.def temp2 = r18
.def state = r19
.def disp1 = r20
.def disp2 = r21
.def interruptFlag = r22

//for keypad
.def row = r20
.def col = r21
.def rmask = r26
.def cmask = r27

.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

//lcd
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_reg
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro
//

.dseg	
	// changed via difficulty settings
	difficulty:
		.byte 1
	countdownTime:
		.byte 1

	// counters for state 1
	startTimerAccumulator:
		.byte 2
	startTimerSecondCounter:
		.byte 1

	// counters for state 2
	resetPotAccumulator:
		.byte 2
	resetPotFailAccumulator:
		.byte 2
	debounceCounter:
		.byte 2

	//random value
	random16Bit:
		.byte 2
	//counter for state 3
	findPotCounter:
		.byte 2
	//LED display for state 3
	pattern:
		.byte 1
	pattern2:
		.byte 1
	//Used to see if the potentiometer value is changing
	oldPotValue:
		.byte 2

	//Used to time the duration of a keypad press
	correctKeyCounter:
		.byte 2
	//Used to hold the current hidden key
	randomRow:
		.byte 1
	randomCol:
		.byte 1
	//Used to keep track of the round number
	numberOfRoundsFinished:
		.byte 1

	//Used to hold the correct code
	key1Row:
		.byte 1
	key1Col:
		.byte 1
	key2Row:
		.byte 1
	key2Col:
		.byte 1
	key3Row:
		.byte 1
	key3Col:
		.byte 1
	//Used to keep track of how many correct digits of the code have been entered
	correctDigitCounter:
		.byte 1

	strobeCounter:
		.byte 2
	strobeFlag:
		.byte 1

.cseg

.org 0x0000
	jmp RESET
.org INT0addr
	jmp PUSH_0
.org INT1addr
	jmp PUSH_1
.org OVF2addr
	jmp TIMER2OVF
.org OVF0addr
	jmp TIMER0OVF
.org ADCCaddr
	rjmp ADC_INT

rjmp RESET

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

RESET:
	
	// stack pointer
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	// initialize dseg values
	clr temp1
	sts	startTimerAccumulator, temp1
	sts	startTimerAccumulator+1, temp1
	sts resetPotAccumulator, temp1
	sts resetPotAccumulator+1, temp1
	sts resetPotFailAccumulator, temp1
	sts resetPotFailAccumulator+1, temp1
	sts debounceCounter, temp1
	sts debounceCounter+1, temp1
	sts findPotCounter, temp1
	sts findPotCounter+1, temp1
	sts strobeFlag, temp1

	sts pattern, temp1
	sts pattern2, temp1
	sts correctKeyCounter, temp1
	sts numberOfRoundsFinished, temp1
	sts correctDigitCounter, temp1

	// initialize countdown values
	ldi temp1, 3
	sts startTimerSecondCounter, temp1

	ldi temp1, 20
	sts difficulty, temp1
	sts countdownTime, temp1
	
	clr temp1
	sts numberOfRoundsFinished, temp1
	sts correctDigitCounter, temp1

	//initialize state to 0 (start screen)
	clr state

	//configure port directions
	ser r16
	out DDRF, r16
	out DDRA, r16
	out DDRC, r16
	out DDRE, r16
	out DDRG, r16
	clr r16
	out PORTF, r16
	out PORTA, r16
	ldi temp1, PORTLDIR
	sts DDRL, temp1

	// configure ADC interrupt
	ldi temp1, (1<<REFS0)|(0<<ADLAR)|(0<<MUX0)
	sts ADMUX, temp1
	ldi temp1, (1<<MUX5)
	sts ADCSRB, temp1
	ldi temp1, (1<<ADEN)|(1<<ADSC)|(1<<ADIE)|(5<<ADPS0)|(1<<5)
	sts ADCSRA, temp1

	// enable external interrupts 1 and 0
	in temp1, EIMSK
	ori temp1, (1 << INT1)|(1 << INT0)
	out EIMSK, temp1
	// configure external interrupts (falling/rising edge)
	ldi temp1, (2 << ISC10 ) | (2 << ISC00 )
	sts EICRA, temp1

	// configure timer 0
	ldi temp1, 0b00000000
	out TCCR0A, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1
	ldi temp1, 1<<TOIE0
	sts TIMSK0, temp1

	// configure timer 2
	ldi temp1, 0b00000000
	sts TCCR2A, temp1
	ldi temp1, 0b00000010
	sts TCCR2B, temp1
	ldi temp1, 1<<TOIE2
	sts TIMSK2, temp1

	//configure timer 3
	ldi temp1, (1 << CS30)
	sts TCCR3B, temp1
	ldi temp1, (1<<WGM30)|(1<<COM3B1)
	sts TCCR3A, temp1
	

	// configure timer 5
	ldi temp1, 0b00000010
	sts TCCR5B, temp1

	// configure LCD 
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	sei
	rjmp START_SCREEN

// 0 state
START_SCREEN:
	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data ' '
	do_lcd_data '1'
	do_lcd_data '6'
	do_lcd_data 's'
	do_lcd_data '1'
	do_lcd_data '('

	//print difficulty
	lds disp1, difficulty
	clr disp2
	Dtens:
		cpi disp1, 10
		brlo Dones
		inc disp2
		subi disp1, 10
		rjmp Dtens
	Dones:
		subi disp2, -'0'
		do_lcd_data_reg disp2

		subi disp1, -'0'
		do_lcd_data_reg disp1
	do_lcd_data ')'

	//skip line
	do_lcd_command 0b11000000 

	do_lcd_data 'S'
	do_lcd_data 'a'
	do_lcd_data 'f'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data 'C'
	do_lcd_data 'r'
	do_lcd_data 'a'
	do_lcd_data 'c'
	do_lcd_data 'k'
	do_lcd_data 'e'
	do_lcd_data 'r'

	// loop until a letter is pressed, or the state changes to 1
	KEYBOARD_MAIN_0:

		// if the state changes to 1, go to the countdown screen
		cpi state, 1
		brne DONT_GO_TO_COUNTDOWN_SCREEN
		do_lcd_command 0b00000001
		rjmp START_COUNTDOWN_SCREEN
		DONT_GO_TO_COUNTDOWN_SCREEN:

		ldi cmask,INITCOLMASK
		clr col

	COL_LOOP_0:
		cpi col,4
		breq KEYBOARD_MAIN_0
		sts PORTL, cmask

		ldi temp1, 0xFF
	DELAY_0: 
		dec temp1
		brne DELAY_0
	
		lds temp1, PINL
		andi temp1, ROWMASK
		cpi temp1, 0x0F
		breq NEXT_COL_0

		ldi rmask, INITROWMASK
		clr row

	ROW_LOOP_0:
		cpi row, 4
		breq NEXT_COL_0
		mov temp2, temp1
		and temp2, rmask
		breq CHECK_0
		inc row
		lsl rmask
		jmp ROW_LOOP_0

	NEXT_COL_0:
		lsl cmask
		inc col
		jmp COL_LOOP_0

	CHECK_0:
		// continue only if a letter was pressed
		cpi col, 3
		brne KEYBOARD_MAIN_0

		cpi row, 0
		breq A
		cpi row, 1
		breq B
		cpi row, 2
		breq C
		cpi row, 3
		breq D

		A:
		ldi temp1, 20
		rjmp DIFF_CHANGE_END
		B:
		ldi temp1, 15
		rjmp DIFF_CHANGE_END
		C:
		ldi temp1, 10
		rjmp DIFF_CHANGE_END
		D:
		ldi temp1, 6
		rjmp DIFF_CHANGE_END

		DIFF_CHANGE_END:
		sts difficulty, temp1
		sts countdownTime, temp1
		do_lcd_command 0b00000001
		rjmp START_SCREEN


//1 state
START_COUNTDOWN_SCREEN:

	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data '2'
	do_lcd_data '1'
	do_lcd_data ' '
	do_lcd_data '1'
	do_lcd_data '6'
	do_lcd_data 's'
	do_lcd_data '1'

	//skip line
	do_lcd_command 0b11000000 

	do_lcd_data 'S'
	do_lcd_data 't'
	do_lcd_data 'a'
	do_lcd_data 'r'
	do_lcd_data 't'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'g'
	do_lcd_data ' '
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data ' '

	//print countdown value
	lds temp1, startTimerSecondCounter
	subi temp1, -'0'
	do_lcd_data_reg temp1

	do_lcd_data '.'
	do_lcd_data '.'
	do_lcd_data '.'

	cpi state, 1
	//eqivalent to breq START_COUNTDOWN_SCREEN
	breq START_COUNTDOWN_SCREEN_JUMP
	rjmp START_COUNTDOWN_SCREEN_CONTINUE
	START_COUNTDOWN_SCREEN_JUMP:
		rjmp START_COUNTDOWN_SCREEN
	START_COUNTDOWN_SCREEN_CONTINUE:
	
	do_lcd_command 0b00000001
	cpi state, 2
	breq RESET_POT_SCREEN
	rjmp HALT

//2 state
RESET_POT_SCREEN:
	do_lcd_data 'R'
	do_lcd_data 'e'
	do_lcd_data 's'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'P'
	do_lcd_data 'O'
	do_lcd_data 'T'
	do_lcd_data ' '
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data ' '
	do_lcd_data '0'
	do_lcd_command 0b11000000 
	do_lcd_data 'R'
	do_lcd_data 'e'
	do_lcd_data 'm'
	do_lcd_data 'a'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'g'
	do_lcd_data ':'
	do_lcd_data ' '

	//print countdown value
	lds disp1, countdownTime
	clr disp2
	tens:
		cpi disp1, 10
		brlo ones
		inc disp2
		subi disp1, 10
		rjmp tens
	ones:
		subi disp2, -'0'
		do_lcd_data_reg disp2

		subi disp1, -'0'
		do_lcd_data_reg disp1

	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '

	// if state is 2, loop
	cpi state, 2
	breq RESET_POT_SCREEN_JUMP
	rjmp RESET_POT_SCREEN_CONTINUE
	RESET_POT_SCREEN_JUMP:
		rjmp RESET_POT_SCREEN
	RESET_POT_SCREEN_CONTINUE:

	do_lcd_command 0b00000001

	// then go to next screen
	cpi state, 3

	breq FIND_POT_SCREEN

	// if state is 7, go to gameover
	cpi state, 7
	breq IS_GAMEOVER
	rjmp NOT_GAMEOVER
	IS_GAMEOVER:
		rjmp GAMEOVER
	NOT_GAMEOVER:

//3 state
FIND_POT_SCREEN:
	do_lcd_data 'F'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'd'
	do_lcd_data ' '
	do_lcd_data 'P'
	do_lcd_data 'O'
	do_lcd_data 'T'
	do_lcd_data ' '
	do_lcd_data 'P'
	do_lcd_data 'o'
	do_lcd_data 's'

	do_lcd_command 0b11000000

	do_lcd_data 'R'
	do_lcd_data 'e'
	do_lcd_data 'm'
	do_lcd_data 'a'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data 'g'
	do_lcd_data ':'
	do_lcd_data ' '

	//print countdown value
	lds disp1, countdownTime
	clr disp2
	Xtens:
		cpi disp1, 10
		brlo Xones
		inc disp2
		subi disp1, 10
		rjmp Xtens
	Xones:
		subi disp2, -'0'
		do_lcd_data_reg disp2

		subi disp1, -'0'
		do_lcd_data_reg disp1

	do_lcd_data ' '
	do_lcd_data ' '
	do_lcd_data ' '

	// go to state 35
	cpi state, 35
	breq GO_TO_FIND_CODE
	rjmp DONT_GO_TO_FIND_CODE
	GO_TO_FIND_CODE:
		clr temp1
		out PORTC, temp1
		do_lcd_command 0b00000001
		rjmp FIND_CODE_SCREEN
	DONT_GO_TO_FIND_CODE:

	// if state is 2, go back to reset POT screen
	cpi state, 2
	breq GO_BACK_TO_RESET_POT
	rjmp FIND_POT_SCREEN_CONTINUE
	GO_BACK_TO_RESET_POT:
		do_lcd_command 0b00000001
		rjmp RESET_POT_SCREEN
	FIND_POT_SCREEN_CONTINUE:

	// if state is 7, go to gameover
	cpi state, 7
	breq POT_IS_GAMEOVER
	rjmp POT_NOT_GAMEOVER
	POT_IS_GAMEOVER:
		rjmp GAMEOVER
	POT_NOT_GAMEOVER:

	rjmp FIND_POT_SCREEN

//35 state
FIND_CODE_SCREEN:
	// on entering this screen, generate random key to be pressed
	// use the first 2 bits from TCNT5L to determine row, use the first 2 bits from TCNT5H to determine column
	lds temp1, TCNT5L
	lds temp2, TCNT5H
	andi temp1, 0b00000011
	andi temp2, 0b00000011
	sts randomRow, temp1
	sts randomCol, temp2
	// randomRow and randomCol now hold 2 random numbers 0-3 used to identify a random key
	do_lcd_data 'P'
	do_lcd_data 'o'
	do_lcd_data 's'
	do_lcd_data 'i'
	do_lcd_data 't'
	do_lcd_data 'i'
	do_lcd_data 'o'
	do_lcd_data 'n'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'o'
	do_lcd_data 'u'
	do_lcd_data 'n'
	do_lcd_data 'd'
	do_lcd_data '!'

	do_lcd_command 0b11000000

	do_lcd_data 'S'
	do_lcd_data 'c'
	do_lcd_data 'a'
	do_lcd_data 'n'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ' '
	do_lcd_data 'n'
	do_lcd_data 'u'
	do_lcd_data 'm'
	do_lcd_data 'b'
	do_lcd_data 'e'
	do_lcd_data 'r'
	
	ldi state, 4
	STATE_4_LOOP:

	// if state changes to 5, go to enter code screen
	cpi state, 5
	breq GO_TO_ENTER_CODE_SCREEN
	rjmp DONT_GO_TO_ENTER_CODE
	GO_TO_ENTER_CODE_SCREEN:
		//turn off motor
		clr temp1
		sts OCR3BL, temp1
		sts OCR3BH, temp1
		//clear screen
		do_lcd_command 0b00000001
		rjmp ENTER_CODE_SCREEN
	DONT_GO_TO_ENTER_CODE:

	// if state changes to 2, go back to potentiometer screens
	cpi state, 2
	breq START_NEW_ROUND
	rjmp DONT_START_NEW_ROUND
	START_NEW_ROUND:
		//turn off motor
		clr temp1
		sts OCR3BL, temp1
		sts OCR3BH, temp1
		//clear screen
		do_lcd_command 0b00000001
		//restart timer
		lds temp1, difficulty
		sts countdownTime, temp1
		rjmp RESET_POT_SCREEN
	DONT_START_NEW_ROUND:

	rjmp STATE_4_LOOP

//5 state
ENTER_CODE_SCREEN:
	do_lcd_data 'E'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data ' '
	do_lcd_data 'C'
	do_lcd_data 'o'
	do_lcd_data 'd'
	do_lcd_data 'e'

	//skip line
	do_lcd_command 0b11000000
	
	lds disp1, correctDigitCounter
	ldi disp2, 16
	PRINT_STARS:
	cpi disp1, 0
	breq STOP_PRINTING_STARS
	do_lcd_data '*'
	dec disp1
	dec disp2
	rjmp PRINT_STARS
	STOP_PRINTING_STARS:

	PRINT_SPACES:
	cpi disp2, 0
	breq STOP_PRINTING_SPACES
	do_lcd_data ' '
	dec disp2
	rjmp PRINT_SPACES
	STOP_PRINTING_SPACES:

	//Scan keyboard until some input is given
	KEYBOARD_MAIN_2:
		ldi cmask,INITCOLMASK
		clr col

	COL_LOOP_2:
		cpi col,4
		breq KEYBOARD_MAIN_2
		sts PORTL, cmask

		ldi temp1, 0xFF
	DELAY_2: 
		dec temp1
		brne DELAY_2
	
		lds temp1, PINL
		andi temp1, ROWMASK
		cpi temp1, 0x0F
		breq NEXT_COL_2

		ldi rmask, INITROWMASK
		clr row

	ROW_LOOP_2:
		cpi row, 4
		breq NEXT_COL_2
		mov temp2, temp1
		and temp2, rmask
		breq CHECK_2
		inc row
		lsl rmask
		jmp ROW_LOOP_2

	NEXT_COL_2:
		lsl cmask
		inc col
		jmp COL_LOOP_2

	CHECK_2:

		//find the current key being checked
		lds temp1, correctDigitCounter
		cpi temp1, 0
		breq KEY_1
		cpi temp1, 1
		breq KEY_2
		cpi temp1, 2
		breq KEY_3

		KEY_1:
			lds temp1, key1Row
			lds temp2, key1Col
			cp temp1, row
			cpc temp2, col
			brne KEY_INCORRECT
			rjmp KEY_CORRECT
		KEY_2:
			lds temp1, key2Row
			lds temp2, key2Col
			cp temp1, row
			cpc temp2, col
			brne KEY_INCORRECT
			rjmp KEY_CORRECT
		KEY_3:
			lds temp1, key3Row
			lds temp2, key3Col
			cp temp1, row
			cpc temp2, col
			brne KEY_INCORRECT
			rjmp KEY_CORRECT

		KEY_CORRECT:
			lds temp1, correctDigitCounter
			inc temp1
			sts correctDigitCounter, temp1
			rjmp CHECK_2_END

		KEY_INCORRECT:
			clr temp1
			sts correctDigitCounter, temp1
			rjmp CHECK_2_END

		CHECK_2_END:
		sts correctDigitCounter, temp1
		cpi temp1, 3
		breq WIN_SCREEN

	rjmp ENTER_CODE_SCREEN

WIN_SCREEN:
	ldi state, 9
	do_lcd_command 0b00000001
	do_lcd_data 'G'
	do_lcd_data 'a'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data 'c'
	do_lcd_data 'o'
	do_lcd_data 'm'
	do_lcd_data 'p'
	do_lcd_data 'l'
	do_lcd_data 'e'
	do_lcd_data 't'
	do_lcd_data 'e'
	
	do_lcd_command 0b11000000

	do_lcd_data 'Y'
	do_lcd_data 'o'
	do_lcd_data 'u'
	do_lcd_data ' '
	do_lcd_data 'W'
	do_lcd_data 'i'
	do_lcd_data 'n'
	do_lcd_data '!'

// loop until something is pressed
KEYBOARD_MAIN_3:
		ldi cmask,INITCOLMASK
		clr col

	COL_LOOP_3:
		cpi col,4
		breq KEYBOARD_MAIN_3
		sts PORTL, cmask

		ldi temp1, 0xFF
	DELAY_3: 
		dec temp1
		brne DELAY_3
	
		lds temp1, PINL
		andi temp1, ROWMASK
		cpi temp1, 0x0F
		breq NEXT_COL_3

		ldi rmask, INITROWMASK
		clr row

	ROW_LOOP_3:
		cpi row, 4
		breq NEXT_COL_3
		mov temp2, temp1
		and temp2, rmask
		breq RESTART_GAME
		rjmp DONT_RESET_GAME
		RESTART_GAME:
		rjmp RESET
		DONT_RESET_GAME:
		inc row
		lsl rmask
		jmp ROW_LOOP_3

	NEXT_COL_3:
		lsl cmask
		inc col
		jmp COL_LOOP_3
	


//7 state
GAMEOVER:
	do_lcd_command 0b00000001
	do_lcd_data 'G'
	do_lcd_data 'a'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data ' '
	do_lcd_data 'o'
	do_lcd_data 'v'
	do_lcd_data 'e'
	do_lcd_data 'r'

	//skip line
	do_lcd_command 0b11000000 

	do_lcd_data 'Y'
	do_lcd_data 'o'
	do_lcd_data 'u'
	do_lcd_data ' '
	do_lcd_data 'L'
	do_lcd_data 'o'
	do_lcd_data 's'
	do_lcd_data 'e'
	do_lcd_data '!'

	GAMEOVER_LOOP:

	cpi state, 0
	//eqivalent to breq RESET
	breq RESET_JUMP
	rjmp RESET_CONTINUE
	RESET_JUMP:
		rjmp RESET
	RESET_CONTINUE:

	rjmp GAMEOVER_LOOP


HALT:
	//something has gone wrong
	out PORTC, state
	rjmp HALT

PUSH_0:
	//debouncing stuff (needed to stop instant advance to state 1 after reset)
	cpi interruptFlag, 0
	breq END_PUSH_0
	//clear the debounce counter
	clr interruptFlag
	clr temp1
	sts debounceCounter, temp1
	sts debounceCounter+1, temp1

	// if the current state is 0, set it to 1
	// if the current state is 7 or 9, reset the game
	cpi state, 0
	breq GO_TO_COUNTDOWN
	rjmp PB_0_RESTART_GAME
	
	GO_TO_COUNTDOWN:
	ldi state, 1
	rjmp END_PUSH_0

	PB_0_RESTART_GAME:
	rjmp RESET

	END_PUSH_0:
	reti

PUSH_1:

	//debouncing stuff (not really necessary)
	cpi interruptFlag, 0
	breq END_PUSH_1
	//clear the debounce counter
	clr interruptFlag
	clr temp1
	sts debounceCounter, temp1
	sts debounceCounter+1, temp1

	// if the current state is 7 or 9, reset the game
	cpi state, 7
	breq PB_1_RESTART_GAME
	cpi state, 9
	breq PB_1_RESTART_GAME
	rjmp END_PUSH_1
	
	PB_1_RESTART_GAME:
	rjmp RESET

	END_PUSH_1:
	reti

TIMER0OVF:
	//prologue
	in temp1, SREG
	push temp1
	push r24
	push r25

	// find out what state and branch accordingly

	cpi state, 1
	brne TIMER_0_NOT_STATE_1
	rjmp TIMER_0_STATE_1
	TIMER_0_NOT_STATE_1:
	
	cpi state, 2
	brne TIMER_0_NOT_STATE_2
	rjmp TIMER_0_STATE_2
	TIMER_0_NOT_STATE_2:

	cpi state, 3
	brne TIMER_0_NOT_STATE_3
	rjmp TIMER_0_STATE_3
	TIMER_0_NOT_STATE_3:

	cpi state, 4
	brne TIMER_0_NOT_STATE_4
	rjmp TIMER_0_STATE_4
	TIMER_0_NOT_STATE_4:

	cpi state, 9
	brne TIMER_0_NOT_STATE_9
	rjmp TIMER_0_STATE_9
	TIMER_0_NOT_STATE_9:

	//otherwise just end
	rjmp TIMER_0_END

	TIMER_0_STATE_1:
		// increment the timer
		lds r24, startTimerAccumulator
		lds r25, startTimerAccumulator + 1
		adiw r25:r24, 1
	
		// check if a second has passed
		cpi r24, low(7812)
		ldi temp1, high(7812)
		cpc r25, temp1

		brne NOT_SECOND

		// if a second has passed, decrement the remaining seconds
		// if a second has passed, clear the accumulator
		// if 0 seconds are left, change the state to 2		
		SECOND:

		//clear accumulator
		clr r24
		clr r25
		sts startTimerAccumulator, r24
		sts startTimerAccumulator + 1, r25

		//decrement remaining seconds
		lds temp1, startTimerSecondCounter
		dec temp1
		sts startTimerSecondCounter, temp1

		//check for 0 seconds left
		//if 0 seconds left, change state, otherwise end interrupt immediately
		cpi temp1, 0
		breq TIMER_0_STATE_CHANGE
		rjmp TIMER_0_END

		//changes to state 2
		TIMER_0_STATE_CHANGE:
		ldi state, 2
		jmp TIMER_0_END

		NOT_SECOND:
		// if a second has not passed, simply store the incremented accumulator value
		sts startTimerAccumulator, r24
		sts startTimerAccumulator + 1, r25
		rjmp TIMER_0_END

	TIMER_0_STATE_2:
		// compare ADCSL and ADCSH to 0
		lds r24, ADCL
		lds r25, ADCH

		clr temp1
		cpi r24, 0
		cpc r25, temp1
		//if potentiometer is set to 0, jump to POT_IS_0, otherwise jump to POT_IS_NOT_0
		breq POT_IS_0
		rjmp POT_IS_NOT_0


		POT_IS_0:
		// get accumulator value
		lds r24, resetPotAccumulator
		lds r25, resetPotAccumulator + 1
		// compare value of accumulator to 3906
		cpi r24, low(3906)
		ldi temp1, high(3906)
		cpc r25, temp1

		// if accumulator has reached 3906, change state to next screen (find POT)
		// otherwise, keep accumulating
		breq CHANGE_STATE
		DONT_CHANGE_STATE:
		adiw r25:r24, 1
		sts resetPotAccumulator, r24
		sts resetPotAccumulator+1, r25
		rjmp POT_TIMEOUT_CHECK
		CHANGE_STATE:

		// if state is 3, generate and store random number
		lds temp1, TCNT5L
		lds temp2, TCNT5H

		sts random16Bit, temp1
		sts random16Bit+1, temp2

		ldi state, 3
		rjmp POT_TIMEOUT_CHECK

		// reset the accumulator to 0
		POT_IS_NOT_0:
		clr temp1
		sts resetPotAccumulator, temp1
		sts resetPotAccumulator, temp1

		POT_TIMEOUT_CHECK:
		//increment accumulator
		//if it reaches 7816, decrement timeout counter
		//if timeout counter reaches 0, change state to gameover screen
		lds r24, resetPotFailAccumulator
		lds r25, resetPotFailAccumulator + 1
		adiw r25:r24, 1
		sts resetPotFailAccumulator, r24
		sts resetPotFailAccumulator+1, r25

		cpi r24, low(7816)
		ldi temp1, high(7816)
		cpc r25, temp1
		breq COUNTDOWN_TO_GAMEOVER
		rjmp TIMER_0_END

		//decrement timeout counter
		//reset the accumulator
		COUNTDOWN_TO_GAMEOVER:

		clr temp1
		sts resetPotFailAccumulator, temp1
		sts resetPotFailAccumulator+1, temp1

		lds temp1, countdownTime
		dec temp1
		sts countdownTime, temp1
		
		//check for timeout
		cpi temp1, 0
		brne POT_NOT_TIMED_OUT
		POT_TIMED_OUT:
		ldi state, 7		
		POT_NOT_TIMED_OUT:
		rjmp TIMER_0_END

	TIMER_0_STATE_3:

		//get the current POT value in r25:r24
		lds r24, ADCL
		lds r25, ADCH
		//get random 10 bit value in temp2:temp1
		lds temp1, random16Bit
		lds temp2, random16Bit+1
		andi temp2, 0b00000011

		
		// compare the two values
		// if POT value > random 10 bit value, jump to POT_TOO_HIGH
		// otherwise go to POT_LOWER_THAN_RAND
		cp r25, temp2
		brlo POT_OK
		breq HIGH_BITS_SAME
		rjmp POT_TOO_HIGH
		HIGH_BITS_SAME:
		cp r24, temp1
		brlo POT_OK
		rjmp POT_TOO_HIGH

		POT_TOO_HIGH:
		ldi state, 2
		clr temp1
		sts pattern, temp1
		sts pattern2, temp1
		rjmp TIMER_0_STATE_3_END

		POT_OK:
		sub temp1, r24
		sbc temp2, r25

		cpi temp2, 0
		brne DIFF_MORE_48

		cpi temp1, 16
		brlo DIFF_LESS_16

		cpi temp1, 32
		brlo DIFF_LESS_32

		cpi temp1, 48
		brlo DIFF_LESS_48
		
		rjmp DIFF_MORE_48

		DIFF_LESS_16:
			//load pattern
			ldi temp1, 0b11111111
			sts pattern, temp1
			ldi temp1, 0b00000011
			sts pattern2, temp1

			//increment counter 
			lds r24, findPotCounter
			lds r25, findPotCounter+1
			adiw r25:r24, 1
			sts findPotCounter+1, r25
			sts findPotCounter, r24

			//compare counter value to 1 second
			cpi r24, low(7812)
			ldi temp1, high(7812)
			cpc r25, temp1

			brne DONT_GO_TO_KEYPAD_SCREEN
			GO_TO_KEYPAD_SCREEN:
			clr temp1
			out PORTC, temp1
			out PORTG, temp1
			ldi state, 35
			rjmp TIMER_0_END
					
			DONT_GO_TO_KEYPAD_SCREEN:
			rjmp TIMER_0_STATE_3_END

		DIFF_LESS_32:
			ser temp1
			sts pattern, temp1
			ldi temp1, 0b00000001
			sts pattern2, temp1
			rjmp CLEAR_POT_COUNTER

		DIFF_LESS_48:
			ser temp1
			sts pattern, temp1
			clr temp1
			sts pattern2, temp1
			rjmp CLEAR_POT_COUNTER

		DIFF_MORE_48:
			clr temp1
			sts pattern, temp1
			sts pattern2, temp1
			rjmp CLEAR_POT_COUNTER

		CLEAR_POT_COUNTER:
		clr temp1
		sts findPotCounter, temp1
		sts findPotCounter+1, temp1
		TIMER_0_STATE_3_END:
		lds temp1, pattern
		out PORTC, temp1
		lds temp1, pattern2
		out PORTG, temp1
		//keep countdown from state 2
		rjmp POT_TIMEOUT_CHECK

	TIMER_0_STATE_4:
		KEYPAD_MAIN:
			// initialize column counter and column mask
			ldi cmask, INITCOLMASK
			clr col
		COL_LOOP:
			//if all columns have been scanned with no result, no buttons are being pressed
			cpi col, 4
			breq GO_TO_NOTHING_PRESSED
			rjmp DONT_GO_TO_NOTHING_PRESSED
			GO_TO_NOTHING_PRESSED:
			rjmp NOTHING_PRESSED
			DONT_GO_TO_NOTHING_PRESSED:

			//column mask to PORTL for taking input
			sts PORTL, cmask

			ldi temp1, 0xFF
			delay: 
			dec temp1
			brne delay
			
			//loop for input
			lds temp1, PINL
			andi temp1, ROWMASK
			cpi temp1, 0x0F
			//if no input, then scan next column
			breq NEXT_COL
			
			//otherwise, there is input and scan through rows to find the pressed button
			//initialize rowmask and row counter
			ldi rmask, INITROWMASK
			clr row		

		ROW_LOOP:
			//if all rows have been scanned, stop scanning rows and go back to scanning columns
			cpi row, 4
			breq NEXT_COL

			//scan through each row
			//if a row is being pressed, go to check to see if the button being pressed is correct
			mov temp2, temp1
			and temp2, rmask
			breq CHECK
			inc row
			lsl rmask
			jmp ROW_LOOP

		NEXT_COL:
			//scan next column
			lsl cmask
			inc col
			jmp COL_LOOP

		CHECK:
			//check if the pressed button is correct
			lds temp1, randomRow
			lds temp2, randomCol

			cp temp1, row
			cpc temp2, col
			brne GO_TO_WRONG_KEY
			rjmp CORRECT_KEY
			GO_TO_WRONG_KEY:
			rjmp WRONG_KEY
			
			CORRECT_KEY:
			//turn on motor
			ser temp1
			sts OCR3BL, temp1
			sts OCR3BH, temp1
	
			//increment timer
			lds r24, correctKeyCounter
			lds r25, correctKeyCounter + 1
			adiw r25:r24, 1
			sts correctKeyCounter, r24
			sts correctKeyCounter+1, r25

			//check if button has been held for long enough
			//if not, just end
			//if so, check the round number
			cpi r24, high(32)
			ldi temp1, low(32)
			cpc r25, temp1
			brne TIMER_0_STATE_4_END

			KEY_HOLD_DONE:
				// increment number of rounds finished
				lds temp1, numberOfRoundsFinished
				
				// save key pressed
				cpi temp1, 0
				breq FIRST_KEY
				cpi temp1, 1
				breq SECOND_KEY
				cpi temp1, 2
				breq THIRD_KEY
				
				// in case something goes wrong
				cpi temp1, 3
				brne KEY_HOLD_DONE
				ldi state, 5
				rjmp TIMER_0_END

				FIRST_KEY:
				lds temp1, randomRow
				lds temp2, randomCol
				sts key1Row, temp1
				sts key1Col, temp2
				ldi state, 2
				ldi temp1, 1
				sts numberOfRoundsFinished, temp1
				rjmp TIMER_0_STATE_4_END

				SECOND_KEY:
				lds temp1, randomRow
				lds temp2, randomCol
				sts key2Row, temp1
				sts key2Col, temp2
				ldi state, 2
				ldi temp1, 2
				sts numberOfRoundsFinished, temp1
				rjmp TIMER_0_STATE_4_END

				THIRD_KEY:
				lds temp1, randomRow
				lds temp2, randomCol
				sts key3Row, temp1
				sts key3Col, temp2
				ldi state, 5
				ldi temp1, 3
				sts numberOfRoundsFinished, temp1
				rjmp TIMER_0_STATE_4_END

			TIMER_0_STATE_4_END:
				rjmp TIMER_0_END


		WRONG_KEY:
		NOTHING_PRESSED:
			//turn off motor
			clr temp1
			sts OCR3BL, temp1
			sts OCR3BH, temp1

			//clear timer
			sts correctKeyCounter, temp1
			sts correctKeyCounter+1, temp1
			rjmp TIMER_0_END	

	TIMER_0_STATE_9:
		lds temp1, strobeFlag
		cpi temp1, 0
		breq STROBE_OFF

		STROBE_ON:
		in temp1, PINA
		ori temp1, 0b00000010
		out PORTA, temp1
		rjmp STROBE_COUNT

		STROBE_OFF:
		in temp1, PINA
		andi temp1, 0b11111101
		out PORTA, temp1
		rjmp STROBE_COUNT

		STROBE_COUNT:
		lds r24, strobeCounter
		lds r25, strobeCounter+1
		adiw r25:r24, 1
		sts strobeCounter, r24
		sts strobeCounter+1, r25

		cpi r25, high(3906)
		ldi temp1, low(3906)
		cpc r24, temp1

		breq TOGGLE_STROBE
		rjmp TIMER_0_END

		TOGGLE_STROBE:
		lds temp1, strobeFlag
		com temp1
		sts strobeFlag, temp1

		clr temp1
		sts strobeCounter, temp1
		sts strobeCounter+1, temp1
		rjmp TIMER_0_END

	TIMER_0_END:
		//epilogue
		pop r25
		pop r24
		pop temp1
		out SREG, temp1
		reti

TIMER2OVF:
	in temp1, SREG
	push temp1
	push r24
	push r25

	lds r24, debounceCounter
	lds r25, debounceCounter + 1
	adiw r25:r24, 1
	cpi r24, low(1600)
	ldi temp1, high(1600)
	cpc r25, temp1
	brne DEBOUNCE_NOTDONE
	DEBOUNCE_DONE:
	ser interruptFlag
	rjmp DEBOUNCE_END
	DEBOUNCE_NOTDONE:
	sts debounceCounter, r24
	sts debounceCounter+1, r25

	DEBOUNCE_END:
	pop r25
	pop r24
	pop temp1
	out SREG, temp1
	reti

ADC_INT:
	reti



