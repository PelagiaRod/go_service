package mid

import (
	"context"
	"fmt"
	"runtime/debug"
)

func Panics(ctx context.Context, handler Handler) (err error) {
	defer func() {
		if rec := recover(); rec != nil {
			trace := debug.Stack()
			err = fmt.Errorf("panic: %v\n%s", rec, trace)
		}
	}()

	return handler(ctx)
}
