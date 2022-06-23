import UIKit



class ViewController: UIViewController {

    let usersUrl = URL(string: "https://jsonplaceholder.typicode.com/users")
    let todolistUrl = URL(string: "https://jsonplaceholder.typicode.com/todos")
    
    private var models:[Codable] = []
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        //fetchUsersData()
        //fetchTodosData()
        Task.init {
            await fetchTodosDataAsync()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    func fetchUsersData(){
        URLSession.shared.customRequest(
            url: usersUrl,
            model: [UserModel].self) {[weak self] result in
                switch result{
                case .success(let users):
                    print(users)
                    DispatchQueue.main.async {
                        self?.models = users
                        self?.tableView.reloadData()
                    }
                case .failure(let error):
                    print(error)
                }
            }
    }
    
    func fetchTodosData(){
        URLSession.shared.customRequest(
            url: todolistUrl,
            model: [TodoModel].self) {[weak self] result in
                switch result{
                case .success(let todos):
                    print(todos)
                    DispatchQueue.main.async {
                        self?.models = todos
                        self?.tableView.reloadData()
                    }
                case .failure(let error):
                    print(error)
                }
            }
    }
    
    func fetchTodosDataAsync() async {
        let result = try? await URLSession.shared.customRequestAsync(
            url: todolistUrl,
            model: [TodoModel].self,
            queryParameters: nil,
            body: nil,
            onFail: {
                print("onFail")
            })
        switch result{
        case .success(let todos):
            print(todos)
            DispatchQueue.main.async {
                self.models = todos
                self.tableView.reloadData()
            }
        case .failure(let error):
            print(error)
        case .none:
            print("none")
        }
    }


}
extension ViewController: UITableViewDelegate,UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let user = models[indexPath.row] as? UserModel
        let todo = models[indexPath.row] as? TodoModel
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = user?.name
        cell.textLabel?.text = todo?.title
        if let item = todo?.completed {
            cell.accessoryType = item ? .checkmark : .none
        }
        return cell
    }
}

extension URLSession{
    enum NetworkError: Error{
        case urlError
        case dataError
    }
    func customRequest<T: Codable>(
        url: URL?,
        model: T.Type,
        completion: @escaping(Result<T,Error>)->Void
    ){
        guard let url = url else {
            completion(.failure(NetworkError.urlError))
            return
        }
        let task = self.dataTask(with: url) { data, _, error in
            guard let data = data else {
                if let error = error {
                    completion(.failure(error))
                }else{
                    completion(.failure(NetworkError.dataError))
                }
                return
            }
            do {
                let result = try JSONDecoder().decode(model, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    func customRequestAsync<T: Codable>(
        url: URL?,
        model:T.Type,
        queryParameters: [String: String]?,
        body: [String: String]?,
        onFail: @escaping () -> ()
    )async throws -> Result<T,Error> {
        guard let url = url else {
            return (.failure(NetworkError.urlError))
        }
        let (data,_) = try await URLSession.shared.data(from: url)

        if let datas = try? JSONDecoder().decode(model, from: data){
            return .success(datas)
        }
        return .failure(NetworkError.dataError)
    }
}
struct UserModel:Codable {
    let name: String
    let email: String
}

struct TodoModel:Codable {
    let title: String
    let completed: Bool
}
