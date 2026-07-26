package web

import (
	"context"
	"errors"
	"net/http"
	"os"
	"syscall"
	"time"

	//"uuid"

	"github.com/google/uuid"
)

// A handler is a type that handles a http request within our own little mini framework.
type Handler func(ctx context.Context, w http.ResponseWriter, r *http.Request) error

// App is the entry point into our application and what configures our context
// object for each of our http handlers. Feel free to add any configuration
// data/logic on this App struct.
type App struct {
	*http.ServeMux
	shutdown chan os.Signal
	mw       []MidHandler
}

func NewApp(shutdown chan os.Signal, mw ...MidHandler) *App {
	return &App{
		ServeMux: http.NewServeMux(),
		shutdown: shutdown,
		mw:       mw,
	}
}

func (a *App) SignalShutdown() {
	a.shutdown <- syscall.SIGTERM
}

func validateError(err error) bool {
	// Example validation logic
	return errors.Is(err, syscall.EINVAL)
}

func (a *App) HandleFunc(pattern string, handler Handler, mw ...MidHandler) {

	handler = wrapMiddleware(mw, handler)
	handler = wrapMiddleware(a.mw, handler)

	h := func(w http.ResponseWriter, r *http.Request) {

		v := Values{
			TraceID: uuid.NewString(),
			Now:     time.Now().UTC(),
		}

		ctx := context.WithValue(r.Context(), key, &v)

		if err := handler(ctx, w, r); err != nil {
			if validateError(err) {
				a.SignalShutdown()
				return
			}
		}
	}

	a.ServeMux.HandleFunc(pattern, h)
}
