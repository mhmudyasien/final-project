import pytest
from app import app, db, Task

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            yield client
            db.drop_all()

def test_health_check(client):
    """Test the health check endpoint."""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'
    assert data['database'] == 'connected'

def test_get_tasks_empty(client):
    """Test getting tasks when the list is empty."""
    response = client.get('/api/tasks')
    assert response.status_code == 200
    assert response.get_json() == []

def test_create_task(client):
    """Test creating a new task."""
    response = client.post('/api/tasks', json={
        'title': 'Test Task',
        'description': 'Test Description'
    })
    assert response.status_code == 201
    data = response.get_json()
    assert data['title'] == 'Test Task'
    assert data['description'] == 'Test Description'
    assert data['completed'] is False
    assert 'id' in data

def test_create_task_no_title(client):
    """Test creating a task without a title (should fail)."""
    response = client.post('/api/tasks', json={
        'description': 'No title'
    })
    assert response.status_code == 400
    assert response.get_json()['error'] == 'Title is required'

def test_update_task(client):
    """Test updating an existing task."""
    # Create a task first
    res = client.post('/api/tasks', json={'title': 'Original Title'})
    task_id = res.get_json()['id']
    
    # Update it
    response = client.put(f'/api/tasks/{task_id}', json={
        'title': 'Updated Title',
        'completed': True
    })
    assert response.status_code == 200
    data = response.get_json()
    assert data['title'] == 'Updated Title'
    assert data['completed'] is True

def test_delete_task(client):
    """Test deleting a task."""
    # Create a task first
    res = client.post('/api/tasks', json={'title': 'To be deleted'})
    task_id = res.get_json()['id']
    
    # Delete it
    response = client.delete(f'/api/tasks/{task_id}')
    assert response.status_code == 204
    
    # Verify it's gone
    response = client.get('/api/tasks')
    assert len(response.get_json()) == 0
