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
}

func NewApp(shutdown chan os.Signal) *App {
	return &App{
		ServeMux: http.NewServeMux(),
		shutdown: shutdown,
	}
}

func (a *App) HandleFunc(pattern string, handler Handler) {

	h := func(w http.ResponseWriter, r *http.Request) {

		// PUT ANY CODE WE WANT HERE

		if err := handler(r.Context(), w, r); err != nil {
			// ERROR HANDLING HERE
			fmt.Println(err)
			return
		}

		// PUT ANY CODE WE WANT HERE
	}

	a.ServeMux.HandleFunc(pattern, h)
}
