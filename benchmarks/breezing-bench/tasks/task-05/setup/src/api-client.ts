export interface ApiResponse<T> {
  data: T;
  status: number;
}

export interface ApiClientOptions {
  baseUrl: string;
  timeout?: number;
  retries?: number;
}

// Naive implementation without error handling
export class ApiClient {
  constructor(private options: ApiClientOptions) {}

  async get<T>(path: string): Promise<ApiResponse<T>> {
    const response = await fetch(`${this.options.baseUrl}${path}`);
    const data = await response.json();
    return { data: data as T, status: response.status };
  }

  async post<T>(path: string, body: unknown): Promise<ApiResponse<T>> {
    const response = await fetch(`${this.options.baseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await response.json();
    return { data: data as T, status: response.status };
  }
}
