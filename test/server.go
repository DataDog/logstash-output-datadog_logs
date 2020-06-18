package main

import (
	"net/http"
	"os"
	"time"
)

func hello(w http.ResponseWriter, req *http.Request) {
	w.WriteHeader(200)
}

func main() {
	go writeLogs()
	http.HandleFunc("/v1/input", hello)
	http.ListenAndServe(":8090", nil)
}

func writeLogs() {
	f, err := os.OpenFile("/home/circleci/project/test/test.log",
		os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		panic(err)
	}
	defer f.Close()
	for {
		if _, err := f.WriteString("Testing...\n"); err != nil {
			panic(err)
		}
		time.Sleep(2 * time.Second)
	}
}
