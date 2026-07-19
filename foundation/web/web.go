package web

import (
	"context"
	"fmt"
	"net/http"
	"os"
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

func (a *App) HandleFunc(pattern string, handler Handler, mw ...MidHandler) {

	handler = wrapMiddleware(mw, handler)
	handler = wrapMiddleware(a.mw, handler)

	h := func(w http.ResponseWriter, r *http.Request) {

		if err := handler(r.Context(), w, r); err != nil {
			// ERROR HANDLING HERE
			fmt.Println(err)
			return
		}
	}

	a.ServeMux.HandleFunc(pattern, h)
}
