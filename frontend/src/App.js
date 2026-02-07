import React, { useState, useEffect } from 'react';
import {
  Container,
  Typography,
  TextField,
  Button,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
  IconButton,
  Checkbox,
  Paper,
  Box,
  CircularProgress,
  Alert,
  Snackbar,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@mui/material';
import { Delete as DeleteIcon, Edit as EditIcon } from '@mui/icons-material';
import axios from 'axios';

const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState({ title: '', description: '' });
  const [editingTask, setEditingTask] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [taskToDelete, setTaskToDelete] = useState(null);

  useEffect(() => {
    fetchTasks();
  }, []);

  const fetchTasks = async () => {
    setLoading(true);
    try {
      const response = await axios.get(`${API_URL}/tasks`);
      setTasks(response.data);
      setError(null);
    } catch (error) {
      setError('Failed to fetch tasks. Please try again later.');
      console.error('Error fetching tasks:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (editingTask) {
        await axios.put(`${API_URL}/tasks/${editingTask.id}`, newTask);
        setSuccess('Task updated successfully!');
      } else {
        await axios.post(`${API_URL}/tasks`, newTask);
        setSuccess('Task created successfully!');
      }
      setNewTask({ title: '', description: '' });
      setEditingTask(null);
      fetchTasks();
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to save task. Please try again.');
      console.error('Error saving task:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteClick = (task) => {
    setTaskToDelete(task);
    setDeleteDialogOpen(true);
  };

  const handleDeleteConfirm = async () => {
    if (!taskToDelete) return;

    setLoading(true);
    try {
      await axios.delete(`${API_URL}/tasks/${taskToDelete.id}`);
      setSuccess('Task deleted successfully!');
      fetchTasks();
    } catch (error) {
      setError('Failed to delete task. Please try again.');
      console.error('Error deleting task:', error);
    } finally {
      setLoading(false);
      setDeleteDialogOpen(false);
      setTaskToDelete(null);
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setNewTask({ title: task.title, description: task.description });
  };

  const handleToggleComplete = async (task) => {
    setLoading(true);
    try {
      await axios.put(`${API_URL}/tasks/${task.id}`, {
        ...task,
        completed: !task.completed,
      });
      fetchTasks();
    } catch (error) {
      setError('Failed to update task. Please try again.');
      console.error('Error updating task:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCloseSnackbar = () => {
    setError(null);
    setSuccess(null);
  };

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Typography variant="h3" component="h1" gutterBottom align="center">
        Task Manager
      </Typography>

      <Paper sx={{ p: 3, mb: 3 }}>
        <form onSubmit={handleSubmit}>
          <TextField
            fullWidth
            label="Task Title"
            value={newTask.title}
            onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
            margin="normal"
            required
            disabled={loading}
          />
          <TextField
            fullWidth
            label="Description"
            value={newTask.description}
            onChange={(e) => setNewTask({ ...newTask, description: e.target.value })}
            margin="normal"
            multiline
            rows={2}
            disabled={loading}
          />
          <Box sx={{ mt: 2, display: 'flex', gap: 2 }}>
            <Button
              type="submit"
              variant="contained"
              color="primary"
              fullWidth
              disabled={loading}
            >
              {loading ? <CircularProgress size={24} /> : (editingTask ? 'Update Task' : 'Add Task')}
            </Button>
            {editingTask && (
              <Button
                variant="outlined"
                color="secondary"
                onClick={() => {
                  setEditingTask(null);
                  setNewTask({ title: '', description: '' });
                }}
                disabled={loading}
              >
                Cancel
              </Button>
            )}
          </Box>
        </form>
      </Paper>

      {loading && !tasks.length ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <List>
          {tasks.map((task) => (
            <ListItem
              key={task.id}
              sx={{
                mb: 1,
                bgcolor: 'background.paper',
                borderRadius: 1,
                '&:hover': { bgcolor: 'action.hover' },
              }}
            >
              <Checkbox
                checked={task.completed}
                onChange={() => handleToggleComplete(task)}
                disabled={loading}
              />
              <ListItemText
                primary={task.title}
                secondary={
                  <>
                    {task.description}
                    <br />
                    <Typography variant="caption" color="text.secondary">
                      Created: {new Date(task.created_at).toLocaleString()}
                    </Typography>
                  </>
                }
                sx={{
                  textDecoration: task.completed ? 'line-through' : 'none',
                }}
              />
              <ListItemSecondaryAction>
                <IconButton
                  edge="end"
                  onClick={() => handleEdit(task)}
                  disabled={loading}
                >
                  <EditIcon />
                </IconButton>
                <IconButton
                  edge="end"
                  onClick={() => handleDeleteClick(task)}
                  disabled={loading}
                >
                  <DeleteIcon />
                </IconButton>
              </ListItemSecondaryAction>
            </ListItem>
          ))}
        </List>
      )}

      <Snackbar
        open={!!error || !!success}
        autoHideDuration={6000}
        onClose={handleCloseSnackbar}
      >
        <Alert
          onClose={handleCloseSnackbar}
          severity={error ? 'error' : 'success'}
          sx={{ width: '100%' }}
        >
          {error || success}
        </Alert>
      </Snackbar>

      <Dialog
        open={deleteDialogOpen}
        onClose={() => setDeleteDialogOpen(false)}
      >
        <DialogTitle>Confirm Delete</DialogTitle>
        <DialogContent>
          Are you sure you want to delete this task?
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleDeleteConfirm} color="error">
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}

export default App;