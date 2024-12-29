package get_up_timer

import "core:fmt"
import "core:strings"
import "core:time"
import "core:thread"
import "core:sync"
import "core:c/libc"
import "core:strconv"

// DEFAULT_DELTA_TIME :: 10 * time.Second  // seconds
DEFAULT_DELTA_TIME :: 30 * time.Minute     // Minutes

EXECUTION_1 :: "aplay get_up_and_start_walking.wav"
EXECUTION_2 :: "aplay get_up_and_start_walking_2.wav"

THREAD_COUNT :: 1

Get_Up_Timer :: struct {

    time_interval     : time.Duration,
    last_get_up_time  : time.Time,
    thread_is_running : bool,
    thread_handler    : ^ thread.Thread,
    execution_string  : cstring,
}

barrier := &sync.Barrier{ }

run :: proc ( ) {

    default_time_interval := DEFAULT_DELTA_TIME

    get_up_timer : ^ Get_Up_Timer = timer_make( default_time_interval )
    defer timer_delete( & get_up_timer )

/*
    ok := start( get_up_timer )
    if ok {
        fmt.printfln( "T1 - Thread started ok" )

        time.sleep( 10 * time.Second )

        fmt.printfln( "T1 - END Thread sleep" )

        stop( get_up_timer )

    } else {
        fmt.printfln( "T1 - Thread started error" )
    }
*/

    usage := `Valid commands are:
    'quit'
    'start'
    'stop'
    'interval=30' in minutes
    'swap_wav'
`

    invalid_usage := `Invalid command!
Valid commands are:
    'quit'
    'start'
    'stop'
    'interval=30' in minutes
    'swap_wav'
`

    fmt.printfln( usage )

    flag_is_running := true
    for  flag_is_running {

        // 1. Read from the terminal buffer.
        // 2. Parse the commands.
        // 3. Execute the commands.

        buf_bytes := [ 100 ]byte{ }

        libc.scanf( "%99s", & buf_bytes  )

        end_index : int = 0
        for i in 0 ..< len( buf_bytes ) {
            if buf_bytes[ i ] == 0 {
                end_index = i
                break
            }
        }

        str_tmp := string(  buf_bytes[ : end_index ] )

        str_tmp_1 := strings.to_lower( strings.trim( str_tmp, " \t\r\n" ) )

        // fmt.printfln( "\"%s\" len( str_tmp_1 ) : %d ", str_tmp_1, len( str_tmp_1 ) )

        if str_tmp_1 == "quit" {
            stop( get_up_timer )
            flag_is_running = false

            continue
        }

        if str_tmp_1 == "start" {
            if get_up_timer.thread_is_running == false {
                start( get_up_timer )
                fmt.printfln( "Timer started running!" )
            } else {
                fmt.printfln( "Timer already running!" )
            }

            continue
        }

        if str_tmp_1 == "stop" {
            if get_up_timer.thread_is_running {
                stop( get_up_timer )
                fmt.printfln( "Timer stoped!" )
            } else {
                fmt.printfln( "Timer was not running!" )
            }

            continue
        }

        if str_tmp_1 == "swap_wav" {
            switch get_up_timer.execution_string {

                case EXECUTION_1 :
                    get_up_timer.execution_string = EXECUTION_2
                    fmt.printfln( "Swaped to %s", EXECUTION_2 )

                case EXECUTION_2 :
                    get_up_timer.execution_string = EXECUTION_1
                    fmt.printfln( "Swaped to %s", EXECUTION_1 )
            }

            continue
        }

        // Parse interval
        pair_str := strings.split( str_tmp_1, "="  )
        if len( pair_str ) != 2 {

            fmt.printfln( "\"%s\" %s", str_tmp_1, invalid_usage )
            continue
        } else {

            if pair_str[ 0 ] != "interval" {

                fmt.printfln( "\"%s\" %s", str_tmp_1, invalid_usage )
                continue
            } else {

                value := pair_str[ 1 ]
                minutes, ok := strconv.parse_int( value )
                if !ok || minutes < 0 || minutes > 180 {

                    fmt.printfln( "Error: interval  must be [ 0, 180 ]" )
                    continue
                } else {

                    // get_up_timer.time_interval = cast( time.Duration ) i64( minutes ) * time.Second
                    get_up_timer.time_interval = cast( time.Duration ) i64( minutes ) * time.Minute

                    new_zero_time_interval := time.time_add( time.Time{ }, get_up_timer.time_interval )
                    new_interval_str := time_to_string( new_zero_time_interval )
                    defer delete( new_interval_str )

                    fmt.printfln( "Inteval set to %v", new_interval_str )
                    continue
                }

            }
        }

    }

}

timer_make :: proc ( default_time_interval : time.Duration ) ->
                     ^ Get_Up_Timer {

    get_up_timer := new( Get_Up_Timer )

    // Initialize fields.
    get_up_timer.time_interval     = default_time_interval
    get_up_timer.last_get_up_time  = time.now( )
    get_up_timer.thread_is_running = false
    get_up_timer.thread_handler    = nil
    get_up_timer.execution_string  = "aplay get_up_and_start_walking.wav"

    return get_up_timer
}

timer_delete :: proc ( get_up_timer : ^^ Get_Up_Timer ) {

    // Stop thread from thread handler and wait for it to join.
    stop( get_up_timer^ )

    free( get_up_timer^ )
    get_up_timer^ = nil
}

start :: proc ( get_up_timer : ^ Get_Up_Timer ) ->
              ( ok : bool ){

    current_time := time.now( )
    get_up_timer.last_get_up_time = current_time

    current_time_str := time_to_string( current_time )
    defer delete( current_time_str )

    interval := time.time_add( time.Time{ }, get_up_timer.time_interval )
    interval_str := time_to_string( interval )
    defer delete( interval_str )


    fmt.printfln( "---> Start time : %v   interval : %v",
                  current_time_str,
                  interval_str )

    // 1. Start the thread of the timer that will be testing the time until it is stoped or ended.
    //    And that played the music, with a libc.system( ) call.
    // 2. Set the thread_id to the created threadID.
    // 3. Change the thread_is_running field to true.

    sync.barrier_init( barrier, THREAD_COUNT + 1 )

    get_up_timer.thread_handler = thread.create_and_start_with_data(
            get_up_timer,
            thread_proc,
        )
    if get_up_timer.thread_handler != nil {
        get_up_timer.thread_is_running = true
        // At this point the barrier will end and the first one will continue
        // and the second thread will start stopping at the barrier.
        // But we make sure the flag is set to true before the thread runs.
        sync.barrier_wait( barrier )
        ok = true
        return ok
    }
    ok = false
    return ok
}

stop :: proc ( get_up_timer : ^ Get_Up_Timer ) {

    // 1. Get the thread handler from the created thread.
    // 2. Stop the thread of the timer that was be testing the time until it is stoped or ended.
    // 3. Change the thread_is_running field to false.

    // Stop thread from thread handler and wait for it to join.
    if get_up_timer.thread_is_running {
        get_up_timer.thread_is_running = false
        thread.join( get_up_timer.thread_handler )
        thread.destroy( get_up_timer.thread_handler )
        get_up_timer.thread_handler = nil
    }
}

thread_proc :: proc ( data : rawptr ) {

    get_up_timer := cast( ^ Get_Up_Timer ) data

    get_up_timer.thread_is_running = true

    // At this point the barrier will end and the first one will continue
    // and the second thread will start stopping at the barrier.
    // But we make sure the flag is set to true before the thread runs.
    sync.barrier_wait( barrier )

    counter : int = 1
    for get_up_timer.thread_is_running {

        current_time : time.Time = time.now( )
        delta_time := time.time_add( get_up_timer.last_get_up_time, get_up_timer.time_interval )
        zero_delta_time := time.time_add( time.Time{ }, get_up_timer.time_interval )

        // fmt.printfln( "delta_time : %v", delta_time )
        // fmt.printfln( "current_time : %v", current_time )

        if  delta_time._nsec < current_time._nsec {
            get_up_timer.last_get_up_time = current_time

            time_str := time_to_string( current_time )
            defer delete( time_str )
            zero_delta_time_str := time_to_string( zero_delta_time )
            defer delete( zero_delta_time_str )

            fmt.printfln( "==> %d Get Up and Start Walking!  time : %s delta : %s ",
                          counter, time_str, zero_delta_time_str )

            // libc.system( "aplay get_up_and_start_walking.wav" )
            libc.system( get_up_timer.execution_string )

            counter += 1
        }

        // Thread sleep 30 seconds.
        time.sleep( 500 * time.Millisecond )
    }

}

time_to_string :: proc ( time_instant : time.Time ) ->
                       ( time_str : string ) {

    time_buf := make( []u8, 20 )
    time_str = time.time_to_string_hms( time_instant, time_buf[ : ] )

    return time_str
}

