package assert

import "slices"
import "fmt"

func Eq(result any, expected any, message string) {
	if result != expected {
		format := "Assertion failed.  \nExpected: %v\n  Got: %v\n  %s"
		msg := fmt.Sprintf(format, expected, result, message+"\n")
		panic(msg)
	}
}

func SliceEq[T comparable](result []T, expected []T, message string) {
	if !slices.Equal(result, expected) {
		format := "Assertion failed:\n  Expected: %v\n  Got: %v\n  %s"
		msg := fmt.Sprintf(format, expected, result, message+"\n")
		panic(msg)
	}
}

func Some[T any](v T, e error) T {
	if e != nil {
		panic(e)
	}
	return v
}

func No(e error) {
	if e != nil {
		panic(e)
	}
}
