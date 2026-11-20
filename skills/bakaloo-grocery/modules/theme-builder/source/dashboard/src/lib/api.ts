import axios from "axios"

const api = axios.create({ baseURL: "/api/builder", timeout: 10_000 })

api.interceptors.response.use(response => response, error => {
  const message = error.response?.data?.message
  return Promise.reject(typeof message === "string" ? new Error(message) : error)
})

export default api
