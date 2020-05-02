defmodule HnliveWeb.StoriesLive do
  use HnliveWeb, :live_view

  def mount(_params, _session, socket) do
    type = Map.get(socket.assigns, :live_action, :top)

    socket =
      assign(socket,
        updated: 0,
        type: type,
        stories: [],
        loading: true,
        timer_ref: nil
      )

    case connected?(socket) do
      false ->
        {:ok, socket}

      true ->
        send(self(), :fetch_stories)
        socket = assign(socket, timer_ref: schedule_refresh())
        {:ok, socket}
    end
  end

  def render(assigns) do
    ~L"""
    <header style="display:flex;justify-content:space-between;align-items:center;">
      <h1><%= get_title(@type) %></h1>

      <button
        type="button"
        class="btn btn-primary"
        style="width:140px;"
        phx-click="refresh"
        <%= if @loading, do: "disabled" %>
      >
        <%= if @loading && length(@stories) > 0 do %>
          <span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>
          Loading...
        <% else %>
          Refresh
        <% end %>
      </button>
    </header>

    <%= if @loading && length(@stories) == 0 do %>
      <div class="spinner-border" role="status">
        <span class="sr-only">Loading...</span>
      </div>
    <% end %>

    <%= if @updated != 0 do %>
      <div style="margin-bottom: 1em;">
        <small>Updated at: <%= Timex.format!(@updated, "{h24}:{m} {Zabbr}") %></small>
      </div>
    <% end %>

    <div>
      <%= for story <- @stories do %>
        <article style="display:block;margin-bottom: 1em;">
          <div>
            <a href="<%= url_or_hn(story.url, story.id) %>"><%= story.title  %></a>
          </div>
          <footer>
            <small>
              <span><%= story.score %> points</span>
              <span>by <%= story.by %></span>
              <span><%= format_time(story.time * 1000) %></span>
              <span><a href="<%= hn_url(story.id)  %>"><%= story.descendants%> comments</a></span>
            </small>
          </footer>
        </article>
      <% end %>
    </div>
    """
  end

  def handle_info(:fetch_stories, socket) do
    type = socket.assigns.type

    socket =
      case get_stories(type) do
        {:ok, stories} ->
          assign(socket,
            updated: Timex.now(),
            stories: stories,
            loading: false
          )

        _ ->
          socket
          |> put_flash(:error, "Failed to load stories")
          |> assign(loading: false)
      end

    {:noreply, socket}
  end

  def handle_info(:auto_refresh, socket) do
    send(self(), :fetch_stories)

    socket =
      assign(socket,
        loading: true,
        timer_ref: schedule_refresh()
      )

    {:noreply, socket}
  end

  def handle_event("refresh", _, socket) do
    send(self(), :fetch_stories)

    socket =
      assign(socket,
        loading: true,
        timer_ref: schedule_refresh(socket.assigns.timer_ref)
      )

    {:noreply, socket}
  end

  defp schedule_refresh(ref \\ nil) do
    if ref !== nil, do: Process.cancel_timer(ref)
    Process.send_after(self(), :auto_refresh, :timer.minutes(5))
  end

  defp url_or_hn(url, id) do
    case url do
      nil -> hn_url(id)
      _ -> url
    end
  end

  defp hn_url(id) do
    "https://news.ycombinator.com/item?id=#{id}"
  end

  defp format_time(time) do
    time = Timex.from_unix(time, :millisecond)
    Timex.from_now(time)
  end

  defp get_stories(type, limit \\ 30) do
    case HN.stories(type) do
      {:ok, stories} ->
        stories =
          stories
          |> Enum.take(limit)
          |> Enum.map(&Task.async(fn -> HN.item!(&1) end))
          |> Enum.map(&Task.await/1)

        {:ok, stories}

      _ ->
        {:error, "Failed to load stories"}
    end
  end

  defp get_title(type) do
    case type do
      :top ->
        "Top Stories"

      :new ->
        "New Stories"

      :best ->
        "Best Stories"

      :ask ->
        "Ask HN Stories"

      :show ->
        "Show HN Stories"

      :job ->
        "Job Posts"

      other ->
        "#{other} Stories"
    end
  end
end
