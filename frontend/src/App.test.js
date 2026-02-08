import { render, screen } from '@testing-library/react';
import App from './App';

test('renders Task Manager title', () => {
    render(<App />);
    const titleElement = screen.getByText(/Task Manager/i);
    expect(titleElement).toBeInTheDocument();
});

test('renders Add Task button', () => {
    render(<App />);
    const buttonElement = screen.getByRole('button', { name: /Add Task/i });
    expect(buttonElement).toBeInTheDocument();
});
