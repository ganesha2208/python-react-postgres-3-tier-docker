import axios from "axios";

const API_URL = import.meta.env.VITE_API_URL || "/api";

const client = axios.create({
  baseURL: API_URL,
  headers: { "Content-Type": "application/json" },
});

export const listItems = () => client.get("/items/").then((r) => r.data);
export const createItem = (data) =>
  client.post("/items/", data).then((r) => r.data);
export const updateItem = (id, data) =>
  client.put(`/items/${id}`, data).then((r) => r.data);
export const deleteItem = (id) =>
  client.delete(`/items/${id}`).then((r) => r.data);
