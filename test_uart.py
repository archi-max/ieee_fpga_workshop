#!/usr/bin/env python3
"""
Simple UART Test Script for Sequence Game
"""

import serial
import time
import sys

def test_uart(port='COM3', baudrate=115200):
    """
    Test UART communication with the FPGA
    
    Args:
        port: Serial port (e.g., 'COM3' on Windows, '/dev/ttyUSB0' on Linux)
        baudrate: Baud rate (should be 115200)
    """
    print(f"Opening serial port {port} at {baudrate} baud...")
    
    try:
        # Open serial port
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=8,
            parity='N',
            stopbits=1,
            timeout=1,
            xonxoff=False,
            rtscts=False,
            dsrdtr=False
        )
        
        # Clear any existing data
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        
        print("Serial port opened successfully!")
        print("Waiting for FPGA messages...")
        print("Commands: 'e' = enter, 'r' = reset, '0'-'7' = toggle bits, 'q' = quit")
        print("-" * 60)
        
        # Main loop
        while True:
            # Check for received data
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                print(f"RX: {data.hex()} -> ", end='')
                
                # Try to decode as ASCII
                try:
                    text = data.decode('ascii')
                    print(f"'{text}'")
                except:
                    print("(non-ASCII)")
            
            # Check for keyboard input (non-blocking on Windows is tricky)
            try:
                import msvcrt  # Windows
                if msvcrt.kbhit():
                    key = msvcrt.getch().decode('ascii')
                    if key == 'q':
                        break
                    print(f"TX: '{key}' ({ord(key):02X})")
                    ser.write(key.encode())
            except ImportError:
                # Linux/Mac - use select
                import select
                if sys.stdin in select.select([sys.stdin], [], [], 0)[0]:
                    key = sys.stdin.read(1)
                    if key == 'q':
                        break
                    print(f"TX: '{key}' ({ord(key):02X})")
                    ser.write(key.encode())
            
            time.sleep(0.01)  # Small delay to prevent CPU overuse
            
    except serial.SerialException as e:
        print(f"Error: {e}")
        print("\nTroubleshooting:")
        print("1. Check that the correct port is specified")
        print("2. Ensure no other program is using the port")
        print("3. Verify the FPGA is connected and programmed")
        
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Serial port closed")

def list_ports():
    """List available serial ports"""
    import serial.tools.list_ports
    
    print("Available serial ports:")
    ports = serial.tools.list_ports.comports()
    
    if not ports:
        print("  No serial ports found")
    else:
        for port in ports:
            print(f"  {port.device}: {port.description}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Test UART communication with FPGA')
    parser.add_argument('--port', default='COM3', help='Serial port (default: COM3)')
    parser.add_argument('--baud', type=int, default=115200, help='Baud rate (default: 115200)')
    parser.add_argument('--list', action='store_true', help='List available ports')
    
    args = parser.parse_args()
    
    if args.list:
        list_ports()
    else:
        print("UART Test for Sequence Game")
        print("=" * 60)
        test_uart(args.port, args.baud)
