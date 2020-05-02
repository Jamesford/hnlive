defmodule HnliveWeb.LayoutView do
  use HnliveWeb, :view

  def nav_link(conn, text, path) do
    active = is_active(conn, path)

    ~E"""
    <li class="nav-item <%= if active, do: "active" %>">
      <a class="nav-link" href="<%= path %>"><%= text %></a>
    </li>
    """
  end

  defp is_active(conn, path) do
    path === Phoenix.Controller.current_path(conn, %{})
  end
end
