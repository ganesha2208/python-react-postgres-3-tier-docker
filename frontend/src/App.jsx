import React, { useEffect, useState } from "react";
import { listItems, createItem, updateItem, deleteItem } from "./api";

const emptyForm = { name: "", description: "", price: "", quantity: "" };

export default function App() {
  const [items, setItems] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [error, setError] = useState("");

  const load = async () => {
    try {
      setItems(await listItems());
    } catch (e) {
      setError("Failed to load items: " + e.message);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const onChange = (e) =>
    setForm({ ...form, [e.target.name]: e.target.value });

  const onSubmit = async (e) => {
    e.preventDefault();
    setError("");
    const payload = {
      name: form.name,
      description: form.description || null,
      price: parseFloat(form.price) || 0,
      quantity: parseInt(form.quantity, 10) || 0,
    };
    try {
      if (editingId) {
        await updateItem(editingId, payload);
      } else {
        await createItem(payload);
      }
      setForm(emptyForm);
      setEditingId(null);
      await load();
    } catch (e) {
      setError(
        e.response?.data?.detail
          ? JSON.stringify(e.response.data.detail)
          : e.message
      );
    }
  };

  const onEdit = (item) => {
    setEditingId(item.id);
    setForm({
      name: item.name,
      description: item.description || "",
      price: String(item.price),
      quantity: String(item.quantity),
    });
  };

  const onCancel = () => {
    setEditingId(null);
    setForm(emptyForm);
  };

  const onDelete = async (id) => {
    if (!window.confirm("Delete this item?")) return;
    try {
      await deleteItem(id);
      await load();
    } catch (e) {
      setError("Delete failed: " + e.message);
    }
  };

  return (
    <div className="container">
      <h1>📦 Items Manager — CI/CD Test ✅</h1>
      <h1>Hello Ganesha congrats you complate this project</h1>
      {error && <div className="error">{error}</div>}

      <form onSubmit={onSubmit}>
        <input
          name="name"
          placeholder="Name"
          value={form.name}
          onChange={onChange}
          required
        />
        <input
          name="description"
          placeholder="Description"
          value={form.description}
          onChange={onChange}
        />
        <input
          name="price"
          type="number"
          step="0.01"
          placeholder="Price"
          value={form.price}
          onChange={onChange}
        />
        <input
          name="quantity"
          type="number"
          placeholder="Quantity"
          value={form.quantity}
          onChange={onChange}
        />
        <div className="actions">
          <button type="submit">{editingId ? "Update" : "Create"}</button>
          {editingId && (
            <button type="button" className="secondary" onClick={onCancel}>
              Cancel
            </button>
          )}
        </div>
      </form>

      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Description</th>
            <th>Price</th>
            <th>Qty</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {items.length === 0 && (
            <tr>
              <td colSpan="6" style={{ textAlign: "center", color: "#888" }}>
                No items yet
              </td>
            </tr>
          )}
          {items.map((it) => (
            <tr key={it.id}>
              <td>{it.id}</td>
              <td>{it.name}</td>
              <td>{it.description}</td>
              <td>{it.price}</td>
              <td>{it.quantity}</td>
              <td className="actions">
                <button onClick={() => onEdit(it)}>Edit</button>
                <button className="danger" onClick={() => onDelete(it.id)}>
                  Delete
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
