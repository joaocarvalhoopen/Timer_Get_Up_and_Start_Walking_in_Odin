
all:
	odin build . --debug -out:./bin/get_up_timer.exe

run_in_clion:
	odin run . --debug -out:./bin/get_up_timer.exe


clean:
	rm -f ./bin/get_up_timer.exe

run:
	./bin/get_up_timer.exe

